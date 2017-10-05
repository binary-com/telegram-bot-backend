package Binary::TelegramBot::Modules::Trade;

use Binary::TelegramBot::WSBridge qw(send_ws_request get_property);
use Binary::TelegramBot::SendMessage qw(send_message);
use Binary::TelegramBot::Helper::Await qw (await_response);
use Binary::TelegramBot::WSResponseHandler qw(forward_ws_response);
use Future;
use JSON qw(decode_json);
use Exporter qw(import);
use Binary::TelegramBot::KeyboardGenerator qw (keyboard_generator merge_keyboards);

our @EXPORT = qw(process_trade subscribe_proposal get_trade_type);

sub process_trade {
    my ($chat_id, $arguments) = @_;
    my @args = split(/ /, $arguments, 4);
    my $length = scalar @args;

    my $response_map = {
        0 => sub {
            my $trade_type = get_trade_type($args[0]);
            my $underlying = $args[1];
            my $payout     = $args[2];
            my $duration   = $args[3];
            return keyboard_generator(
                'Please select a trade type',
                [
                    ['Digit Matches', "/trade DIGITMATCH $underlying $payout $duration"],
                    ['Digit Differs', "/trade DIGITDIFF $underlying $payout $duration"],
                    ['Digit Over',    "/trade DIGITOVER $underlying $payout $duration"],
                    ['Digit Under',   "/trade DIGITUNDER $underlying $payout $duration"],
                    ['Digit Even',    "/trade DIGITEVEN $underlying $payout $duration"],
                    ['Digit Odd',     "/trade DIGITODD $underlying $payout $duration"]
                ],
                3, $$trade_type[0]
            );
        },
        1 => sub {
            my $trade_type = $args[0];
            my $payout     = $args[2];
            my $duration   = $args[3];

            # return if ask_for_barrier($chat_id, $args[0]);    #Check if contract requires barrier.

            return keyboard_generator(
                'Please select an underlying',
                [
                    ['Volatility Index 10',  "/trade $trade_type R_10 $payout $duration"],
                    ['Volatility Index 25',  "/trade $trade_type R_25 $payout $duration"],
                    ['Volatility Index 50',  "/trade $trade_type R_50 $payout $duration"],
                    ['Volatility Index 75',  "/trade $trade_type R_75 $payout $duration"],
                    ['Volatility Index 100', "/trade $trade_type R_100 $payout $duration"]
                ],
                2, get_underlying_name($args[1])
            );
        },
        2 => sub {
            my $trade_type = $args[0];
            my $underlying = $args[1];
            my $duration   = $args[3];
            my $currency   = get_property($chat_id, "currency");
            return keyboard_generator(
                'Please select a payout',
                [
                    ["5 $currency",   "/trade $trade_type $underlying 5 $duration"],
                    ["10 $currency",  "/trade $trade_type $underlying 10 $duration"],
                    ["25 $currecncy", "/trade $trade_type $underlying 25 $duration"],
                    ["50 $currency",  "/trade $trade_type $underlying 50 $duration"],
                    ["100 $currency", "/trade $trade_type $underlying 100 $duration"]
                ],
                3, "$args[2] $currency"
            );
        },
        3 => sub {
            my $trade_type = $args[0];
            my $underlying = $args[1];
            my $payout     = $args[2];
            return keyboard_generator(
                'Please select a duration',
                [
                    ['5 ticks',  "/trade $trade_type $underlying $payout 5"],
                    ['6 ticks',  "/trade $trade_type $underlying $payout 6"],
                    ['7 ticks',  "/trade $trade_type $underlying $payout 7"],
                    ['8 ticks',  "/trade $trade_type $underlying $payout 8"],
                    ['9 ticks',  "/trade $trade_type $underlying $payout 9"],
                    ['10 ticks', "/trade $trade_type $underlying $payout 10"]
                ],
                3, "$args[3] ticks"
            );
            # send_message({
            #         chat_id      => $chat_id,
            #         text         => $response,
            #         reply_markup => {inline_keyboard => $keys}});
        },
        4 => sub {
            my ($trade_type, $barrier) = split(/_/, $args[0], 2);
            my $underlying = $args[1];
            my $payout     = $args[2];
            my $duration   = $args[3];
            # send_proposal(
            #     $chat_id,
            #     {
            #         underlying    => $underlying,
            #         payout        => $payout,
            #         contract_type => $trade_type,
            #         duration      => $duration,
            #         barrier       => $barrier
            #     });
        }
    };

    my $keyboard = [];

    for( my $i = 0; $length <= 4 && $i < ($length || 4); $i++) {
        # In case of first request run the loop at least four times
        my $keys = $response_map->{$i}(@args);
        $keyboard = merge_keyboards($keyboard, $keys);
    }

    return {
            chat_id      => $chat_id,
            text         => $response,
            reply_markup => {inline_keyboard => $keyboard}};
}

sub ask_for_barrier {
    my ($chat_id, $args) = @_;
    my ($trade_type, $barrier) = split(/_/, $args, 2);
    my @requires_barrrier = qw(DIGITMATCH DIGITDIFF DIGITUNDER DIGITOVER);
    if (grep(/^$trade_type$/, @requires_barrrier) && $barrier eq '') {
        my $arr_keys = [
            ['1', "/trade ${trade_type}_1"],
            ['2', "/trade ${trade_type}_2"],
            ['3', "/trade ${trade_type}_3"],
            ['4', "/trade ${trade_type}_4"],
            ['5', "/trade ${trade_type}_5"],
            ['6', "/trade ${trade_type}_6"],
            ['7', "/trade ${trade_type}_7"],
            ['8', "/trade ${trade_type}_8"]];
        unshift @$arr_keys, ['0', "/trade ${trade_type}_0"] if ($trade_type ne 'DIGITUNDER');
        push @$arr_keys,    ['9', "/trade ${trade_type}_9"] if ($trade_type ne 'DIGITOVER');
        my $keys = keyboard_generator('Please select a digit', $arr_keys, 4);
        return 1;
    }
    return 0;
}

sub send_proposal {
    my ($chat_id, $params) = @_;
    my $request = {
        proposal      => 1,
        amount        => $params->{payout},
        basis         => 'payout',
        contract_type => $params->{contract_type},
        currency      => get_property($chat_id, "currency"),
        duration      => $params->{duration},
        duration_unit => 't',
        symbol        => $params->{underlying}};
    $request->{barrier} = $params->{barrier} if $params->{barrier} ne '';
    my $future = send_ws_request($chat_id, $request);
    $future->on_ready(
        sub {
            my $response = $future->get;
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
    return;
}

sub subscribe_proposal {
    my ($chat_id, $contract_id) = @_;
    my $request = {
        proposal_open_contract => 1,
        contract_id            => $contract_id,
        subscribe              => 1
    };
    my $future = Future->new;
    send_ws_request(
        $chat_id, $request,
        sub {
            my ($chat_id, $response) = @_;
            my $resp_obj = decode_json($response);
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
}

sub get_trade_type {
    my $arguments = shift;
    my @args      = split(/_/, $arguments, 2);
    my $name      = {
        "DIGITMATCH" => "Digit Matches",
        "DIGITDIFF"  => "Digit Differs",
        "DIGITOVER"  => "Digit Over",
        "DIGITUNDER" => "Digit Under",
        "DIGITEVEN"  => "Digit Even",
        "DIGITODD"   => "Digit Odd"
    }->{$args[0]};
    return [$name, $args[1]];
}

sub get_underlying_name {
    my $symbol = shift;
    return {
        R_10  => "Volatility Index 10",
        R_25  => "Volatility Index 25",
        R_50  => "Volatility Index 50",
        R_75  => "Volatility Index 75",
        R_100 => "Volatility Index 100"
    }->{$symbol};
}

1;
