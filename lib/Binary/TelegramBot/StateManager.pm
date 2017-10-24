package Binary::TelegramBot::StateManager;

use strict;
use warnings;

use Exporter qw(import);
use Data::Dumper;
use DBI;

our @EXPORT = qw(set_table create_table insert update get disconnect row_exists remove_table sanitize delete_row);

my $driver = "SQLite";
my $db     = "Users.db";
my $dbh    = DBI->connect("DBI:$driver:dbname=$db", "", "", {RaiseError => 1})
    or die $DBI::errstr;
my $table = 'users';    #Default is users

sub set_table {
    $table = sanitize(shift);
}

sub get_table {
    return $table;
}

sub create_table {
    my $stmt = qq(
        CREATE TABLE IF NOT EXISTS $table
        (
            messageid INT PRIMARY KEY NOT NULL,
            token TEXT NOT NULL,
            loginid TEXT NOT NULL,
            currency TEXT NOT NULL,
            balance FLOAT NOT NULL
        );
    );
    $dbh->do($stmt) or die $DBI::errstr;
}

sub insert {
    my ($chat_id, $token, $authorize) = @{sanitize(\@_)};
    my $stmt = qq(
        INSERT INTO $table
        (messageid, token, loginid, currency, balance)
        VALUES($chat_id, "$token", "$authorize->{loginid}", "$authorize->{currency}", "$authorize->{balance}");
    );
    $dbh->do($stmt) or die $DBI::errstr;
}

sub update {
    my ($chat_id, $field, $value) = @{sanitize(\@_)};
    my $stmt = qq(
        UPDATE $table SET $field = "$value" where messageid=$chat_id;
    );
    $dbh->do($stmt) or die $DBI::errstr;
}

sub delete_row{
    my ($chat_id) = @{sanitize(\@_)};
    my $stmt = qq(DELETE FROM $table where messageid=$chat_id);
    $dbh->do($stmt) or die $DBI::errstr;
}

sub get {
    my ($chat_id, $fields) = @{sanitize(\@_)};
    $fields = $fields || "*";
    if (ref($fields) eq "ARRAY") {
        $fields = join ", ", @$fields;
    }
    my $stmt = qq(
        SELECT $fields FROM $table WHERE messageid = $chat_id;
    );
    my $sth    = $dbh->prepare($stmt);
    my $rv     = $sth->execute() or die $DBI::errstr;
    my @result = $sth->fetchrow_array();
    return @result;
}

sub row_exists {
    my $chat_id = sanitize(shift);
    my $stmt    = qq(select 1 from $table where messageid=$chat_id);
    my $sth     = $dbh->prepare($stmt);
    my $rv      = $sth->execute();
    my @result  = $sth->fetchrow_array();
    return $result[0];
}

sub remove_table {
    my $stmt = qq( drop table $table);
    my $rv   = $dbh->do($stmt);
}

sub disconnect {
    $dbh->disconnect();
}

# Recursive function to sanitize scalar, arrays, and hashes even if they're encapsulated within each other.
sub sanitize {
    my $input = shift;
    # return unless $input;
    if (ref($input) eq "ARRAY") {
        my @arr = @$input;
        foreach (@arr) {
            $_ = sanitize($_);
        }
        $input = \@arr;
    } elsif (ref($input) eq "HASH") {
        foreach (keys %$input) {
            $input->{$_} = sanitize($input->{$_});
        }
    } else {
        $input =~ s/(['"])/\\$1/g;
    }
    return $input;
}

1;
