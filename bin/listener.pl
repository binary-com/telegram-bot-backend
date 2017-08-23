use Data::Dumper;
use Mojolicious::Lite;
use Mojo::Log;
use JSON qw(decode_json);
use FindBin;    # locate this script
use lib "$FindBin::Bin/../lib";
use Binary::TelegramBot::TelegramCommandHandler qw(process_message);

app->config(
    hypnotoad => {
        listen             => ['http://*:3000'],
        workers            => 1,
        inactivity_timeout => 3600,
        heartbeat_timeout  => 120,
    });
app->log(
    Mojo::Log->new(
        path  => '/tmp/mojo.log',
        level => 'warn'
    ));

my $log = app->log;
my $processed_messages = {};

sub listener {
    any '/telegram' => sub {
        my $self      = shift;
        my $req       = $self->req;
        my $msg_obj   = decode_json($req->content->asset->{content});
        my $update_id = $msg_obj->{update_id};
        if (!defined($processed_messages->{$update_id})) {
            $processed_messages->{$update_id} = 1;
            my $msg = $msg_obj->{callback_query}->{data} || $msg_obj->{message}->{text};
            my $chat_id = $msg_obj->{callback_query}->{message}->{chat}->{id} || $msg_obj->{message}->{chat}->{id};
            process_message($chat_id, $msg);
        }
        $self->render(text => "Ok");
    };

    app->start;
}

listener();
