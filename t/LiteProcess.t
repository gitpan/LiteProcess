# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl LiteProcess.t'

#########################

use Test::More tests => 25;
BEGIN { use_ok('LiteProcess') };
use Data::Dumper;

#########################

sub validateProcessCreation($) {
	my $arg = shift;
	ok( defined $arg ) or return 2;
	qx{ps -elfww | grep "$arg"};
	return ( $?>>8 );
}

sub fatal($) {
	ok(shift) or die;
}

my $tN   = 0;
my @pids = ();
$p = new LiteProcess();
ok( $p, "Creation of process object" );
for ( $i = 0 ; $i < 5 ; $i++ ) {
	$pids[$i] = $p->createProcess( "printf", $i+5 );
	$tN++;
	is( &validateProcessCreation( $pids[$i] ), 0, "Process Creation $tN" );

	print "Spawned Process : $pids[$i]\n";
}
is( $p->runAll(), 5, "Running all processes" );
$tN++;
is( $p->run( $p->createProcess( "echo", "6" ) ),
	1, "Create and run only one process - Process Creation $tN" );
$tN++;
is( $p->run( $p->createProcess( "echo", "Kamal Mehta" ) ),
	1, "Create and run only one process - Process Creation $tN" );
my %testHash = $p->waitForAll();
ok( %testHash, "Processes returned" );
diag("Checking Number of processes returned...");
is( keys %testHash, 7, "Checked Process Count" );

$pid = $p->createProcess( "sleep", "1" );
$tN++;
is( &validateProcessCreation($pid), 0, "Process Creation $tN" );
is( $p->run($pid),                  1 );
$testHash = $p->waitFor($pid);
print Dumper($testHash);
ok( $testHash, "Process returned" );
diag("\nChecking Number of processes returned...\n");
ok( $testHash, "Checked Process Count" );
ok( $p->getProcessStatus() );

diag("\nTesting exec failure...\n\n");
is($p->createProcess(),-1);
is($p->createProcess("abc"),undef);
