package Code::Tooling::Util::Transform;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use List::Util 1.45 ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

our @EXPORT_OK = qw[
    &extract_key
    &group_by
    &path_to_tree
    &prune
    &split_array_equally
];

sub extract_key ($data, %opts) {

    ($opts{key})
        || die 'You must specify a key';

    my ($key, $sort, $uniq) = @opts{qw[ key sort uniq ]};

    my @output;
    foreach my $datum ( @$data ) {
        (exists $datum->{$key})
            || die "Could not find key($key) in data(" . $datum . ")";

        push @output => $datum->{$key};
    }

    if ( $sort ) {
        @output = sort @output               if $sort->{ordering} eq 'str';
        @output = sort { $a <=> $b } @output if $sort->{ordering} eq 'num';
        @output = reverse @output            if $sort->{direction} eq 'desc';
    }

    if ( $uniq ) {
        if ( $sort && $sort->{ordering} ) {
            @output = List::Util::uniqstr( @output ) if $sort->{ordering} eq 'str';
            @output = List::Util::uniqnum( @output ) if $sort->{ordering} eq 'num';
        }
        else {
            @output = List::Util::uniq( @output );
        }
    }

    return \@output;
}

sub group_by ($data, %opts) {

    ($opts{key})
        || die 'You must specify a key';

    my $key = $opts{'key'};

    my %output;
    foreach my $datum ( @$data ) {
        (exists $datum->{$key})
            || die "Could not find key($key) in data(" . $datum . ")";

        $output{ $datum->{$key} } = [] unless $output{ $datum->{$key} };
        push @{ $output{ $datum->{$key} } } => $datum;
    }

    return \%output;
}

sub path_to_tree ($data, %opts) {

    my ($path_key, $path_seperator) = @opts{qw[ path_key path_seperator ]};

    my $root = {
        name     => 'ROOT', # the name of the node
        children => [],     # the descendants
        #contents => undef,  # contents of the node
    };

    foreach my $datum ( @$data ) {
        my @path = split $path_seperator, $datum->{ $path_key };

        my $current = $root;
        while ( my $part = shift @path ) {

            if ( my $match = List::Util::first { $_->{name} eq $part } $current->{children}->@* ) {
                $current = $match;
            }
            else {
                push $current->{children}->@* => $current = {
                    name     => $part,
                    children => [],
                    #contents => undef,
                };
            }
        }

        $current->{contents} = $datum;
    }

    return $root;
}

sub prune ($data, %opts) {

    my $exclude = $opts{exclude};
    my @keys    = $opts{keys}->@*;

    my @output;
    foreach my $datum ( @$data ) {
        my %pruned;

        if ( $exclude ) {
            %pruned = %$datum;
            delete @pruned{ @keys };
        }
        else {
            @pruned{ @keys } = @{$datum}{ @keys };
        }

        push @output => \%pruned;
    }

    return \@output;
}

sub split_array_equally ($array, $cnt_groups) {
    die 'invalid first arg, expected array ref' if( !defined($array) || ref $array ne 'ARRAY');
    die 'invalid second arg, expected positive integer' unless( $cnt_groups && $cnt_groups =~ /^\d+$/);
    return [] if ($array->@*) == 0;

    $cnt_groups = scalar( $array->@* ) if( $array->@* < $cnt_groups );
    my $array_groups = [];
    my $min_seg_size = int( ($array->@*) / $cnt_groups );
    my $cnt_large_segs = ($array->@*) % $cnt_groups;
    push $array_groups->@*, _make_n_arrays_of_size_k_from_offset($array, $cnt_large_segs, ( $min_seg_size + 1 ), 0)->@*;
    push $array_groups->@*, _make_n_arrays_of_size_k_from_offset($array, $cnt_groups - $cnt_large_segs, ($min_seg_size), ($min_seg_size+1)*$cnt_large_segs)->@*;
    return $array_groups;
}

sub _make_n_arrays_of_size_k_from_offset ($array,$n,$k,$offset) {
    my $arrays = [];
    foreach ( 1..$n ) {
        my $arr = [];
        push $arr->@* , map { $array->[$offset++] } (1..$k);
        push $arrays->@* , $arr;
    }
    return $arrays;
}

1;

__END__
