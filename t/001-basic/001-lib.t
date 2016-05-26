#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use Test::More;

use experimental qw[
    signatures
    postderef
];

use Data::Dumper;
use Importer 'Code::Tooling::Util::List'       => qw[ split_array_in_equal_groups ];

my $good_arrays = [
	[1,1,1,1,1,1,1,1,1,1,1,3,43,1,123,1,11,1,21,1,31,12,1],

	[],

	[undef,undef,undef],

	[undef],

	[1,1,1,21,1,3,43,1,123,1,11,1,21,1,31,12,1,'e',23,23,23,123,12,32,343,423,
	4234,{},[],1,21,1,3,43,1,123,1,11,1,21,1,31,12,1,'e',23,23,23,123,12,32,,1,1,1,21,1,3,43,1,123,
	1,11,1,21,1,31,12,1,'e',23,23,23,123,12,32,,1,1,1,21,1,3,43,1,123,1,11,1,21,1,31,12,1,'e',23,
	23,23,{yo=>'a',asdf=>'s'},12,32,1,1,1,21,1,3,43,1,123,1,11,1,21,1,31,12,1,'e',23,23,23,123,12,32,1,1,1,21,1],

	[1,1,1,1,1,1,1,1,1,1,1,3,43,1,123,1,11,1,21,1,31,12,1],

	[ {yo=>'a',asdf=>'s'},{some=>'111',are=>' cool'},{},[2,6,6,],[], undef ],

	[ (1...100000)],	
];
my $bad_arrays = [ undef,'pizza','asdf','ih89',0,-123,-1, 1231 ];
my $good_segment_counts = [ (1..10),14,100,10000,1, ];
my $bad_segment_counts = [ undef,'pizza',0,-123,-1,-99999, {a=>'a','d'=>4},[1,1,1] ];

sub copy ($input) {
	return undef if( !defined($input));
	return [$input->@*] if( ref $input eq 'ARRAY' );	
	return {$input->%*} if( ref $input eq 'HASH' );
	return $input;
}

sub test_split_array_in_equal_groups ($array_ref, $segment_count, $result_expected) {
	# taking deep copy of each case
	my $array = copy ($array_ref);	
	my $segments = copy ($segment_count);

	# get the output
	my $splited_array = split_array_in_equal_groups($array, $segments);

	# analyze the data
	if($result_expected) {
		isnt( $splited_array, undef, "should not return undef for valid input" );
		is( ref $splited_array, 'ARRAY', "should return a proper array ref" );

		my ($mn,$mx);
		$mx = 0;
		$mn = $splited_array->@* ? $splited_array->[0]->@* : 0;

		my @merged_array = map{ 
			$mx = $mx < $_->@* ? $_->@* : $mx;
			$mn = $mn > $_->@* ? $_->@* : $mn;
			$_->@*;
		} $splited_array->@*;
		is_deeply(\@merged_array, $array,'array after merging should become the previous array');

		if( $array->@* >= $segments){
			is($splited_array->@*, $segments,"element count in array should be number of segments");
		} else {
			is($splited_array->@*, $array->@*,"element count in array should be emement cnt in main array");
		}
		cmp_ok( $mx-$mn, '<=', 1, "number of elements in min group and max group should be as close as possible" );
	} else {
		is ($splited_array, undef, "should return undef for invalid input" );
	}
}

sub bulk_test_split_array_in_equal_groups ($arrays, $segment_counts, $result_expected) {
	for my $array_ref ($arrays->@*){
		for my $segment_count ($segment_counts->@*){
			test_split_array_in_equal_groups($array_ref,$segment_count, $result_expected);
		}
	}
}

subtest 'split_array_in_equal_groups_bad_tests' => sub  {
	bulk_test_split_array_in_equal_groups($bad_arrays, [ $good_segment_counts->@* , $bad_segment_counts->@* ], 0);
	bulk_test_split_array_in_equal_groups([$good_arrays->@*, $bad_arrays->@*] , $bad_segment_counts, 0);	
};

subtest 'split_array_in_equal_groups_good_tests' => sub  {
	bulk_test_split_array_in_equal_groups($good_arrays, $good_segment_counts, 1);
};

done_testing;