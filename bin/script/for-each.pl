#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();
use Data::Dumper ();
use IPC::Run     ();

use Importer 'Code::Tooling::Util::JSON' => qw[ decode encode ];

our $DEBUG = 0;

sub main {

    my ($bin, $script, $input);
    Getopt::Long::GetOptions(
        'bin=s'    => \$bin,
        'script=s' => \$script,
        'input=s'  => \$input,
        # debug
        'verbose'  => \$DEBUG,
    );

    $input ||= join '' => <STDIN>;
    my $all_args = decode( $input );

    warn "Got input: $input and turned it into: " . Data::Dumper::Dumper($all_args)
        if $DEBUG;

    my @output;
    foreach my $args ( @$all_args ) {

        my $local_bin    = delete $args->{bin}    || $bin    || die 'No bin specified';
        my $local_script = delete $args->{script} || $script || die 'No script specified';

        my @cmd = ( $local_bin, $local_script, %$args );

        my ($out, $err);
        IPC::Run::run( \@cmd, \undef, \$out, \$err )
            or warn 'Unable to run [' . (join ' ' => @cmd) . '] because: ' . $err;

        push @output => {
            bin    => $local_bin,
            script => $local_script,
            args   => $args,
            cmd    => \@cmd,
            output => decode($out),
        };
    }

    print encode( \@output );
}

main && exit;


1;
