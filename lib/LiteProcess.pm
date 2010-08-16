use 5.008008;

package LiteProcess;

use IO::Pty 1.03;
use IO::Tty qw(TIOCSCTTY TIOCNOTTY TCSETCTTY);

use strict 'refs';
use strict 'vars';
use strict 'subs';
use POSIX qw(:sys_wait_h :unistd_h); # For Using WNOHANG and isatty functions
use Fcntl; # For checking file handle contants.
use Carp qw(cluck croak carp confess);
use IO::Handle ();

require Exporter;
use AutoLoader;

@LiteProcess::ISA = qw(IO::Pty Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use LiteProcess ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION;
our %SUPPORTED_SIGNALS ;
my $errno;

BEGIN {
	$LiteProcess::VERSION = '0.01';
	%LiteProcess::SUPPORTED_SIGNALS = (
		SIGHUP    => 1,
		SIGINT    => 2,
		SIGQUIT   => 3,
		SIGILL    => 4,
		SIGTRAP   => 5,
		SIGABRT   => 6,
		SIGBUS    => 7,
		SIGFPE    => 8,
		SIGKILL   => 9,
		SIGUSR1   => 10,
		SIGSEGV   => 11,
		SIGUSR2   => 12,
		SIGPIPE   => 13,
		SIGALRM   => 14,
		SIGTERM   => 15,
		SIGSTKFLT => 16,
		SIGCHLD   => 17,
		SIGCONT   => 18,
		SIGSTOP   => 19,
		SIGTSTP   => 20,
		SIGTTIN   => 21,
		SIGTTOU   => 22,
		SIGURG    => 23,
		SIGXCPU   => 24,
		SIGXFSZ   => 25,
		SIGVTALRM => 26,
		SIGPROF   => 27,
		SIGWINCH  => 28,
		SIGIO     => 29,
		SIGPWR    => 30,
		SIGSYS    => 31
	);
}

sub new() {
	my $class = shift;
	$class = ref($class) if ref($class);
	my ($_self) = new IO::Pty;
	die "$class: Could not assign a pty" unless $_self;
	bless $_self => $class;
	$_self->autoflush(1);
	return $_self;
}

sub createProcess() {
	my $class  = shift;
	my $_this;
	if (ref($class)) {
		$_this = $class;
	}
	else {
	       $_this = $class->new();
	}
	my $_signal = shift or return -1;
	my $_cmd;
	if ( !exists $SUPPORTED_SIGNALS{$_signal} ) {
		$_cmd    = $_signal;
		$_signal = "SIGSTOP";
	}
	else {
		$_cmd = shift;
	}
	my @_args = @_;
	my $_pid  = undef;

	# set up pipe to detect childs exec error
	pipe(STDRDR, STDWTR) or die "Cannot open pipe: $!";
	STDWTR->autoflush(1);

	$_pid = fork();
	unless (defined ($_pid)) {
		warn "Cannot fork: $!";
		return undef;
	}

	unless ($_pid) {
		#CHILD PROCESS SPACE
		close STDRDR;
		$_this->make_slave_controlling_terminal();
		my $slv = $_this->slave();
		close($_this);
		$slv->set_raw();

		# wait for parent before we detach
		open(STDIN,"<&". $slv->fileno()) or die "Couldn't reopen STDIN for reading, $!\n";
		open(STDOUT,">&". $slv->fileno()) or die "Couldn't reopen STDOUT for writing, $!\n";
		open(STDERR,">&". $slv->fileno()) or die "Couldn't reopen STDERR for writing, $!\n";
		close $slv;
		{exec( "$_cmd", @_args ) };
		print STDWTR $!+0;
		die("Cannot exec($_cmd): $!\n");
	}
	#PARENT PROCESS SPACE
	close STDWTR;
	$_this->close_slave();
	$_this->set_raw();

	# NOW WAIT FOR CHILD EXEC (EOF DUE TO CLOSE-ON-EXIT) OR EXEC ERROR
	my $errstatus = sysread(STDRDR, $errno, 256);
	die "Cannot sync with child: $!" if not defined $errstatus;
	close STDRDR; # SO CHILD GETS EOF AND CAN GO AHEAD

	if ($errstatus) {
		$! = $errno+0;
		die "Cannot exec(\"$_cmd\"): $!";
	}

	if ( kill( "$_signal", $_pid ) == 1 ) {
		${*$_this}{STATUS}->{$_pid} = 0;
	}
	return $_pid;
}

sub run() {
	my $_this   = shift;
	my @_pids   = @_;
	my $counter = @_pids;
	my $cnt     = 0;
	if ( @_pids == 0 ) {
		die(
			qq{
			\n\t****Which process to start?******
			\n\t****Process ID is undefined****\n}
		);
	}
	if ( ( $cnt = kill( "SIGCONT", @_pids ) ) != $counter ) {
		return 111;
	}
	return $cnt;
}

sub runAll() {
	my $_this = shift;
	foreach ( keys %{ ${*_this}{STATUS} } ) {
		return 111 if !kill( "SIGCONT", $_ ) == 1;
	}
	return keys %{ ${*$_this}{STATUS} };
}

sub getAllChildProcesses() {
	my $_this = shift;
	return keys( %{ ${*$_this}{STATUS} } );
}

sub getProcessStatus() {
	my $_this   = shift;
	my @_pids   = @_ || keys( %{ ${*$_this}{STATUS} });
	my %_status;

	foreach (@_pids) {
		$_status{$_} = ${*$_this}{STATUS}->{$_};
	}
	return %_status;
}

sub waitForAll() {
	my $_this   = shift;
	while (wait()!=-1) {
		${*$_this}{STATUS}->{$_} = $? >> 8;
	}
	return %{ ${*$_this}{STATUS} };
}

sub waitFor() {
	my $_this  = shift;
	my $_pid   = shift;
	my $retPid = waitpid( $_pid, 0 );
	${*$_this}{STATUS}->{$retPid} = $? >> 8;
	return ${*$_this}{STATUS};
}

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&LiteProcess::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('LiteProcess', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__

=head1 NAME

LiteProcess - Perl extension for synchronized process creation in background and store their return status in object

=head1 SYNOPSIS

  use LiteProcess;
  $p = new LiteProcess();
   
  $pid = $p->createProcess( "SIGSTOP", "sleep", "100" );
     # or
  $pid = $p->createProcess( "sleep", "50" );
   
  $p->runAll();  #runs all the processes which were created using the createProcess()
     # or
  $p->run($pid); #runs all the process given as its argument(@pid or $pid)
   
  $p->waitForAll(); # waits for all the processes created by the createProcess();
     # or
  $p->waitFor($pid); #waits all the process given as its argument(@pid or $pid)

=head1 DESCRIPTION

  This module creates the separate process in background for synchronized child creation control and keeping 
  track of those children.

=head1 EXIT CODES and RETURN VALUES

   createProcess()
   	Returns the process id.
   
   run()
   	Returns 111 if the created process is not started.
   
   runAll()
   	Returns 111 if the created process is not started.
   
   getAllChildProcesses()
   	Returns the list of process id which are created by the object.
   
   getProcessStatus()
   	Returns the list of return status of all the processes created by the object if process
   	is not finished, it's return status is zero.
   
   waitFor()
   	Returns the status of the finished process which is given as its argument.
   
   waitForAll()
   	Returns the status of the all processes created by the object.

=head1 BUGS

Please report bugs.

=head1 AUTHOR

Kamal Mehta, E<lt>kamal@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Kamal Mehta

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
