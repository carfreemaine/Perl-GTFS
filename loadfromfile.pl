#!/usr/bin/perl -w
use strict;
use Text::CSV_XS;
use Tie::Handle::CSV;
use DBI;

my $data = {
    path_to_data => "input",
    database => "sfmta_gtfs",
    username => "mperkins",
    password => "secret",
};

my @tablenames = qw/agency calendar calendar_dates routes stops trips stop_times/;

open($data->{fh}, '>', qq[$data->{path_to_data}/$data->{database}/load-data.sql]) or die "Could not open file for writing SQL commands: $!";
my $fh = $data->{fh};

print $fh "USE " . $data->{database} . "\;\n\n";

foreach my $table (@tablenames) {
    print "Loading $table\n";
    loadtable($table, $data);
    print "$table loaded\n";
}

sub loadtable {
    my $table = shift;
    my $data = shift;
    my $path_to_data = $data->{path_to_data};
    my $database = $data->{database};
    my $username = $data->{username};
    my $password = $data->{password};
    my $outfh = $data->{fh};

    my $csvparser = Text::CSV_XS->new( { binary => 1, blank_is_undef => 1, empty_is_undef => 1, allow_whitespace => 1} );
    my $csv_fh = Tie::Handle::CSV->new("$path_to_data/$database/$table.txt", header => 1, csv_parser => $csvparser );
    my @fieldslist = @{$csv_fh->header};
    my $fieldstring = "(" . (join ",", @fieldslist) . ")";
    
    my $loaddataquery = qq[LOAD DATA LOCAL INFILE '$path_to_data/$database/$table.txt' REPLACE INTO TABLE $table COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\\r\\n' IGNORE 1 LINES ];

    if ($table eq "stop_times") {
        $fieldstring =~ s/arrival_time/\@avar/;
        $fieldstring =~ s/departure_time/\@dvar/;
        $loaddataquery .= $fieldstring . q[ SET arrival_time=NULLIF(@avar,''),departure_time=NULLIF(@dvar,'')];
        if ($fieldstring =~ /shape_dist_traveled/) {
            $loaddataquery =~ s[shape_dist_traveled][\@svar];
            $loaddataquery .= q[,shape_dist_traveled=NULLIF(@svar,'')];
        }
    } else {
        $loaddataquery .= $fieldstring;
    }
    close $csv_fh;

    print $outfh "TRUNCATE TABLE $table\;\n";
    print $outfh "$loaddataquery\;\n";
    print $outfh "\n";

    #$dbh->disconnect;
}
