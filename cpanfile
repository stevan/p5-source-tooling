
use v5.22;

# Core
requires 'experimental'     => 0;
requires 'Importer'         => 0;
requires 'Getopt::Long'     => 0;
requires 'Path::Class'      => 0;
requires 'Data::Dumper'     => 0;

# Core-ish
requires 'JSON::XS'         => 0;
requires 'List::Util'       => 1.45;

# Web
requires 'Plack'            => 0;

# Analysis
requires 'PPI'              => 0;
requires 'Perl::Critic'     => 0;
requires 'Git::Repository'  => 0;
requires 'MetaCPAN::Client' => 0;

# Testing
requires 'Test::More'       => 0;
requires 'Test::Fatal'      => 0;
