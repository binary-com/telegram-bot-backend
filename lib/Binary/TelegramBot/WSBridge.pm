package Binary::TelegramBot::WSBridge;

use Mojo::UserAgent;
use JSON qw(encode_json decode_json);
use Future;

use Exporter qw(import);
use Data::Dumper;
use Binary::TelegramBot::StateManager qw (set_table create_table insert update get row_exists delete_row);
# To do use Mojolicious stash for storing all the values.

our @EXPORT_OK = qw(send_ws_request is_authenticated get_property);

my $app_id = "6660";
my $ws_url = "wss://ws.binaryws.com/websockets/v3?app_id=$app_id";
my $ua     = Mojo::UserAgent->new;
$ua = $ua->inactivity_timeout(60);    #Close connection in 30 seconds
my $req_id          = 1;
my $tx_hash         = {};
my $future_hash     = {};
my $queued_requests = ();

# Preping database.
set_table("users");
create_table();

# $cb -> callback for subscribe request
sub send_ws_request {
    my ($chat_id, $req, $cb) = @_;
    my $future = Future->new;
    $req->{req_id} = $req_id;
    $future_hash->{$chat_id}->{$req_id} = $future;
    $future_hash->{$chat_id}->{$req_id} = $cb if $cb;

    if (!$tx_hash->{$chat_id}->{tx}) {
        if (!$req->{authorize}) {
            push @$queued_requests,
                {
                chat_id => $chat_id,
                req     => $req,
                auth    => 1
                };
            authorize($chat_id, {authorize => get_property($chat_id, "token")})
                if row_exists($chat_id);
        } else {
            authorize($chat_id, $req);
        }
    } else {
        _send($chat_id, $req);
    }

    return $future;
}

sub on_connct {
    my ($tx, $chat_id) = @_;
    print "Connected\n";
    $tx_hash->{$chat_id}->{tx} = $tx;
    send_queued_requests($chat_id);
}

sub on_msg {
    my ($msg, $chat_id) = @_;
    return if !$msg;
    my $resp_obj = decode_json($msg);
    my $req_id   = $resp_obj->{req_id};
    if (ref($future_hash->{$chat_id}->{$req_id}) eq "Future") {
        $future_hash->{$chat_id}->{$req_id}->done($msg);
    }
    # For subscribe requests.
    if (ref($future_hash->{$chat_id}->{$req_id}) eq "CODE") {
        $future_hash->{$chat_id}->{$req_id}->($chat_id, $msg);
    }
    # Save token for future references.
    if ($resp_obj->{msg_type} eq "authorize" && !$resp_obj->{error}) {
        update_state($resp_obj, $chat_id);
    }

    # Delete token.
    if ($resp_obj->{msg_type} eq "logout" && !$resp_obj->{error}) {
        delete_state($resp_obj, $chat_id);
    }

   send_queued_requests($chat_id);
}

sub authorize {
    my ($chat_id, $req) = @_;
    $req->{passthrough} = {reauthorizing => 1} if row_exists($chat_id);
    if (!$tx_hash->{$chat_id}->{tx}) {
        push @$queued_requests,
            {
            chat_id => $chat_id,
            req     => $req,
            auth    => 0
            };
        open_websocket($chat_id);
    } else {
        my $tx = $tx_hash->{$chat_id}->{tx};
        _send($chat_id, $req);
    }
}

#It pretty much just updates the state
sub update_state {
    my ($resp, $chat_id) = @_;
    $tx_hash->{$chat_id}->{authorized} = 1;
    if (row_exists($chat_id)) {
        update($chat_id, "token",    $resp->{echo_req}->{authorize});
        update($chat_id, "loginid",  $resp->{authorize}->{loginid});
        update($chat_id, "currency", $resp->{authorize}->{currency});
        update($chat_id, "balance",  $resp->{authorize}->{balance});
    } else {
        insert($chat_id, $resp->{echo_req}->{authorize}, $resp->{authorize});
    }
}

sub delete_state {
    my ($resp, $chat_id) = @_;
    delete $tx_hash->{$chat_id};
    delete_row($chat_id) if row_exists($chat_id);
}

# Create a ws connection for every chat session.
sub open_websocket {
    my ($chat_id) = @_;
    $ua->websocket(
        $ws_url => sub {
            my ($ua, $tx) = @_;
            print "WebSocket handshake failed!\n" and return
                unless $tx->is_websocket;

            $tx->on(
                message => sub {
                    my ($tx, $msg) = @_;
                    on_msg($msg, $chat_id);
                });
            $tx->on(
                finish => sub {
                    print 'Connection closed' . "\n";
                    my ($tx, $msg) = @_;
                    $tx_hash->{$chat_id}->{tx}         = undef;
                    $tx_hash->{$chat_id}->{authorized} = 0;
                });
            on_connct($tx, $chat_id);
        });
    #Mojo::IOLoop->start unless Mojo::IOLoop->is_running;    # Start IO loop if it isn't already running
}

sub _send {
    my ($chat_id, $req) = @_;
    my $tx = $tx_hash->{$chat_id}->{tx};
    $req_id++;
    $tx->send(encode_json($req));
}

sub send_queued_requests {
    my $chat_id = shift;
    my $length  = scalar @$queued_requests;
    for (my $i = 0; $i < $length; $i++) {
        if (@$queued_requests[$i] && @$queued_requests[$i]->{chat_id} == $chat_id) {
            my $tx  = $tx_hash->{$chat_id}->{tx};
            my $req = @$queued_requests[$i]->{req};
            if (@$queued_requests[$i]->{auth} == 1 && $tx_hash->{$chat_id}->{authorized}) {
                _send($chat_id, $req);
                splice @$queued_requests, $i, 1;
            } elsif (!@$queued_requests[$i]->{auth}) {
                _send($chat_id, $req);
                splice @$queued_requests, $i, 1;
            }
        }
    }
}

sub is_authenticated {
    my $chat_id       = shift;
    my $authenticated = row_exists($chat_id);
    return $authenticated;
}

sub get_property {
    my ($chat_id, $property) = @_;
    my @result = get($chat_id, $property);
    return $result[0];
}

1;
