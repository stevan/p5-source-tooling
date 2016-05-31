package Code::Tooling::Git;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Git::Repository;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, %args) {
    return bless {
        repo => Git::Repository->new( %args )
    } => $class;
}

# ...

sub grep ($self, $pattern, $query) {
    my $cmd = $self->{repo}->command(
        grep => (
            '--break',
            '--heading',
            '--line-number',
        ) => $pattern
    );
    warn '[' . (join ' ' => $cmd->cmdline) . ']' if $query->{debug};
    my @all = $cmd->final_output;

    warn join "\n" => @all if $query->{debug};

    my @files;

    my $current;
    while ( @all ) {
        $current = {
            path    => (shift @all), # first file name
            matches => [],
        };
        while ( my $match = shift @all ) {
            my ($line_num, $line) = ($match =~ /^(\d+)\:(.*)$/);
            push $current->{matches}->@* => {
                line_num => $line_num,
                line     => $line,
            };
        }
        push @files => $current;
    }

    return \@files;
}

sub show ($self, $sha, $query) {

    my $cmd = $self->{repo}->command(
        show => (
            '--date=iso',
            '--format=format:' . (
                join '%n' => (
                    '%H',  # commit hash
                    '%an', # author name
                    '%ae', # author email
                    '%ad', # author date respecting --date
                    '%B',  # body
                    '%H',  # close
                )
            ),
            '--numstat',
            '--summary',
        ) => $sha
    );
    warn '[' . (join ' ' => $cmd->cmdline) . ']' if $query->{debug};
    my @all = $cmd->final_output;

    #return [ 200, [], [ join "\n" => @all ]];

    die 'This should never happen, looking for (' . $sha . ') but found (' . $all[0] . ") in:\n" . (join "\n" => @all)
        if $all[0] ne $sha;

    shift @all; # discard this line, we already have the sha
    my $author_name  = shift @all;
    my $author_email = shift @all;
    my $author_date  = shift @all;
    # now collect the message
    my @body;
    push @body => shift @all
        while @all && $all[0] ne $sha;
    shift @all; # discard the closing commit line

    utf8::decode($author_name);

    # collect all the file details ...
    my %files;
    while ( @all && $all[0] =~ /^\d+/ ) {
        my $line = shift @all;
        my ($added, $removed, $path) = split /\s+/ => $line;
        $files{ $path } = {
            path    => $path,
            added   => $added,
            removed => $removed
        };
    }

    while ( @all && $all[0] =~ /^\s[create|delete]/ ) {
        my $line = shift @all;
        #warn $line;
        my ($action, $path) = ($line =~ /^\s(.*) mode \d+ (.*)/);
        #warn join ", " => $action, $path;
        $files{ $path }->{action} = $action;
    }

    shift @all while @all && $all[0] =~ /^\s*$/; # discard the empty newlines

    return {
        sha     => $sha,
        author  => { name => $author_name, email => $author_email },
        date    => ($author_date . ''),
        message => (join "\n" => @body),
        files   => [ values %files ],
    };
}

sub blame {
    my ($self, $path, $query) = @_;

    my $line_range;
    if ( $query->{start} || $query->{end} ) {
         $line_range = join ',' => (($query->{start} || 1), ($query->{end} || ()));
    }

    my $cmd = $self->{repo}->command(
        blame => (
            '-l',  # use the long version of the SHAs
            ($line_range ? ('-L ' . $line_range) : ()),
        ) => $path
    );
    warn '[' . (join ' ' => $cmd->cmdline) . ']' if $query->{debug};
    my @all = $cmd->final_output;

    #return [ 200, [], [ join "\n" => @all ]];

    foreach my $i ( 1 .. scalar @all ) {

        #warn $all[ $i - 1 ];

        my ($sha, $info) = ($all[ $i - 1 ] =~ /([0-9a-f]{39,40})\s[A-Za-z0-9_\.\/]*\s*\((\w*[^\)]*)\)/);

        # first we ...
        # we match the line number
        my ($line_num) = ($info =~ /\s+(\d+)$/);
        # then strip off the line number
        $info =~ s/\s+\d+$//;
        # next we ...
        # extract the date by anchoring
        # from the rear of the string
        my ($date) = ($info =~ /([0-9-:+\s]*)$/);
        # then we ...
        # make sure to trim the leading
        # spaces that come along
        $date =~ s/^\s*//;
        # then we ...
        # use that same regexp to remove
        # the date so we are left with
        # only the author's name
        $info =~ s/([0-9-:+\s]*)$//;

        utf8::decode($info);

        $all[ $i - 1 ] = +{
            sha      => $sha,
            author   => $info,
            date     => $date,
            line_num => $line_num,
        };
    }

    return \@all;
}

sub log {
    my ($self, $path, $query) = @_;

    my $cmd = $self->{repo}->command(
        log => (
            '--date=iso',
            '--format=format:' . (
                join '%n' => (
                    '%H',  # commit hash
                    '%an', # author name
                    '%ae', # author email
                    '%ad', # author date respecting --date
                    '%B',  # body
                    '%H',  # close
                )
            ),
            # Support a few of the query limiting options
            ($query->{max_count} ? ('--max-count=' . $query->{max_count}) : ()),
            ($query->{skip}      ? ('--skip='      . $query->{skip}     ) : ()),
            ($query->{since}     ? ('--since='     . $query->{since}    ) : ()),
            ($query->{after}     ? ('--after='     . $query->{after}    ) : ()),
            ($query->{until}     ? ('--until='     . $query->{until}    ) : ()),
            ($query->{before}    ? ('--before='    . $query->{before}   ) : ()),
            ($query->{author}    ? ('--author='    . $query->{author}   ) : ()),
            ($query->{commiter}  ? ('--commiter='  . $query->{commiter} ) : ()),
        ) => $path
    );
    warn '[' . (join ' ' => $cmd->cmdline) . ']' if $query->{debug};
    my @all = $cmd->final_output;

    #return [ 200, [], [ join "\n" => @all ]];

    my @commits;
    while ( @all ) {
        my $sha          = shift @all;
        my $author_name  = shift @all;
        my $author_email = shift @all;
        my $author_date  = shift @all;
        # now collect the message
        my @body;
        push @body => shift @all
            while @all && $all[0] ne $sha;
        shift @all; # discard the closing commit line

        utf8::decode($author_name);

        # and push onto commits
        push @commits => {
            sha     => $sha,
            author  => { name => $author_name, email => $author_email },
            date    => ($author_date . ''),
            message => (join "\n" => @body),
        };
    }

    return \@commits;
}

1;

__END__
