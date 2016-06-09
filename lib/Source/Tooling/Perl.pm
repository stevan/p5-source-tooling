package Source::Tooling::Perl;

use v5.22;
use warnings;
use experimental qw[
    signatures
    lexical_subs
];

use Perl::Critic     ();
use version          ();
use Module::CoreList ();
use Module::Runtime  ();

use Source::Tooling::Perl::MetaCPAN;
use Source::Tooling::Perl::Stats::File;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, %args) {

    $args{perl_version} = version->parse( $args{perl_version} )->numify
        if $args{perl_version};

    return bless {
        _metacpan => Source::Tooling::Perl::MetaCPAN->new( @{ $args{metacpan_args} || [] } ),
        # hash slices FTW
        %args{qw[
            perlcritic_profile
            perl_version
        ]},
    } => $class;
}

# metacpan

sub metacpan { $_[0]->{_metacpan} }

# general module stuff

sub is_core_module ($self, $module) {
    !! Module::CoreList::is_core( $module, undef, $self->{perl_version} || () );
}

sub is_module_deprecated ($self, $module) {
    !! Module::CoreList::is_deprecated( $module, $self->{perl_version} || () );
}

sub classify_modules ($self, @modules) {
    return [
        map +{
            is_core => ($self->is_core_module( $_ ) ? 1 : 0),
            name    => $_,
            path    => Module::Runtime::module_notional_filename( $_ ),
        }, @modules
    ];
}

# Perl::Critic oriented stuff

sub critique ($self, $path, $query) {

    ($self->{perlcritic_profile} && -f $self->{perlcritic_profile})
        || die 'The Perl::Critic profile must be set to a valid file path before running the `critique` method';

    my $critic     = Perl::Critic->new( -profile => $self->{perlcritic_profile} );
    my @violations = $critic->critique( $path->stringify );
    my $statistics = $critic->statistics;

    return {
        statistics => {
            modules    => $statistics->modules,
            subs       => $statistics->subs,
            statements => $statistics->statements,
            violations => {
                total => $statistics->total_violations,
            },
            lines      => {
                total    => $statistics->lines,
                blank    => $statistics->lines_of_blank,
                comments => $statistics->lines_of_comment,
                data     => $statistics->lines_of_data,
                perl     => $statistics->lines_of_perl,
                pod      => $statistics->lines_of_pod,
            },
        },
        violations => [
            map +{
                severity    => $_->severity,
                description => $_->description,
                policy      => $_->policy,
                source => {
                    code     => $_->source,
                    location => {
                        line   => $_->line_number,
                        column => $_->column_number,
                    },
                },
            }, @violations
        ]
    }
}

1;

__END__
