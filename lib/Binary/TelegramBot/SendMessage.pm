package Binary::TelegramBot::SendMessage;

use strict;
use warnings;

use Mojo::UserAgent;
use Exporter qw(import);
use Data::Dumper;
use JSON qw(decode_json);
use Future;

# This should be used for only communicating with telegram.

our @EXPORT = qw(send_message);

my $ua         = Mojo::UserAgent->new;
my $token      = $ENV{'TELEGRAM_BOT'};
my $update_url = "https://api.telegram.org/bot$token/sendMessage";

# Returns a future which can be used to determine the completion of a request.
sub send_message {
    my ($reply) = @_;
    my $future = Future->new;
    $reply->{parse_mode} = "Markdown";
    $ua->post(
        "$update_url" => json => $reply => sub {
            my ($agent, $tx) = @_;
            #todo better error handling.
            my $result = decode_json($tx->result->body);
            if ($result->{error_code}) {
                print "$result->{description}\n";
                $future->fail($result->{description});
                return;
            }
            $future->done($result);
        });

    return $future;
}

1;
