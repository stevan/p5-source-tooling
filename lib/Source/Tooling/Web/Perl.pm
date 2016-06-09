package Source::Tooling::Web::Perl;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Plack::Request;

use Importer 'Source::Tooling::Util::JSON' => qw[ encode ];

# Constants

use constant PERLDOC_URL_TEMPLATE  => 'http://perldoc.perl.org/%s';
use constant METACPAN_URL_TEMPLATE => 'https://metacpan.org/search?search_type=modules&q=%s';

# PSGI applications

sub critique ($env) {
    my $r    = Plack::Request->new( $env );
    my $path = $env->{'source.tooling.env.CHECKOUT'}->subdir( $r->path );

    return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
        unless -e $path;

    return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
        if -d $path;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $env->{'source.tooling.obj.PERL'}->critique( $path, $r->query_parameters ) ) ]
    ];
}

sub perldoc ($env) {
    my $r    = Plack::Request->new( $env );
    my $name = substr $r->path, 1;
    my $args = $r->query_parameters;
    my $func_name = $args->{f};

    my @cmd  = ($env->{'source.tooling.env.PERLDOC_BIN'}, '-o', 'HTML');
    if($name){
        push @cmd, $name;
    }
    elsif($func_name){
        push @cmd, "-f $func_name";
    }
    else{
        return [ 400, [], [ 'You must specify either a package name or a function name' ]];
    }

    my @html = `@cmd`;
    return [ 200, [ 'Content-Type' => 'text/html' ], [ @html ]];
}

sub classify_module ($env) {
    my $r          = Plack::Request->new( $env );
    my @modules    = grep $_, split /\,/ => ($r->path =~ s/^\///r); #/
    my $classified = $env->{'source.tooling.obj.PERL'}->classify_modules( @modules );

    my $perl_lib_root = $env->{'source.tooling.env.PERL_LIB_ROOT'};
    my $checkout      = $env->{'source.tooling.env.CHECKOUT'};

    # do some enhancement/fixup for the benefit
    # of a UI that is using this API
    foreach my $module ( @$classified ) {
        my $path = $perl_lib_root->file( $module->{path} )
                            ->relative( $checkout )
                            ->stringify;
        if ( -f $path ) {
            $module->{path}     = $path;
            $module->{is_local} = 1;
        }
        else {
            $module->{is_local} = 0;
            $module->{url}      = $module->{is_core}
                ? (sprintf PERLDOC_URL_TEMPLATE, ($module->{path} =~ s/\.pm$/\.html/r)) #/
                : (sprintf METACPAN_URL_TEMPLATE, $module->{name});
            delete $module->{path};
        }
    }

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $classified ) ]
    ];
}

1;

__END__
