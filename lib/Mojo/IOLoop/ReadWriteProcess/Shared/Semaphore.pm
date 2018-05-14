package Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore;
use Mojo::Base -base;

use Carp;
use POSIX qw(O_WRONLY O_CREAT O_NONBLOCK O_NOCTTY);
use IPC::SysV
  qw(ftok IPC_NOWAIT IPC_CREAT IPC_EXCL S_IRUSR S_IWUSR S_IRGRP S_IWGRP S_IROTH S_IWOTH SEM_UNDO);
use IPC::Semaphore;

use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};
has key  => sub { shift->_genkey };
has _sem => sub { $_[0]->_create(shift->key) };
has count  => 1;
has _value => 1;

sub _genkey { ftok($0, 0) }

# The following is an adaptation over IPC::Semaphore::Concurrency
sub _create {
  my ($self, $key) = @_;

  # Try acquiring already existing semaphore
  my $sem = IPC::Semaphore->new($key, $self->count, 0);
  unless (defined $sem) {
    warn "[debug:$$] Create semaphore $key" if DEBUG;
    $sem = IPC::Semaphore->new($key, $self->count,
      IPC_CREAT | IPC_EXCL | S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH
        | S_IWOTH);
    confess 'Semaphore creation failed! ' unless defined($sem);
    $sem->setall($self->_value);
  }
  return $sem;
}

sub acquire {
  my $self = shift;
  my %args = @_ % 2 == 0 ? @_ : @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : ();

  # Defaults
  $args{'sem'}  = 0  unless defined($args{'sem'});
  $args{'wait'} = 0  unless defined($args{'wait'});
  $args{'max'}  = -1 unless defined($args{'max'});
  $args{'undo'} = 1  unless defined($args{'undo'});
  warn "[debug:$$] Acquire semaphore " . $self->key if DEBUG;

  my $sem   = $self->_sem;
  my $flags = IPC_NOWAIT;
  $flags |= SEM_UNDO if ($args{'undo'});

  my ($ret, $ncnt);

# Get blocked process count here to retain Errno (thus $!) after the first semop call.
  $ncnt = $self->getncnt($args{'sem'}) if ($args{'wait'});
  if ($args{'wait'}) {
    return $ret if ($args{'max'} >= 0 && $ncnt >= $args{'max'});
    warn "[debug:$$] Semaphore wait";

    # warn "[debug:$$] Semaphore val " . $self->getval($args{sem});

    # Remove NOWAIT and block
    $flags ^= IPC_NOWAIT;

    #return $sem->op($args{'sem'}, -1, $flags);
  }

  return $sem->op($args{'sem'}, -1, $flags);
  return $ret;
}


sub getall { shift->_sem->getall() }

sub getval { shift->_sem->getval(shift // 0) }

sub getncnt { shift->_sem->getncnt(shift // 0) }

sub setall { shift->_sem->setall(@_) }

sub setval { shift->_sem->setval(@_) }

sub stat { shift->_sem->stat() }

sub id { shift->_sem->id() }

sub release { shift->_sem->op(shift || 0, 1, 0) }

sub remove { shift->_sem->remove() }

!!42;
