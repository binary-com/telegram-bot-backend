package Binary::TelegramBot::KeyboardGenerator;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw |keyboard_generator merge_keyboards|;

=head2 keyboard_generator

Accepts title, and keys in the format [['Key text', 'Callback data']] and number of keys in a row.
Returns telegram compatible keys.

=cut

sub keyboard_generator {
    my ($title, $keys, $keys_per_row) = @_;
    my @keyboard;
    push @keyboard,
        [{
            text          => $title,
            callback_data => 'undef'
        }];

    while (scalar @$keys) {
        my @row;
        for(1..$keys_per_row) {
            next unless scalar @$keys;
            my @key = @{shift @$keys};
            push @row, { text => $key[0], callback_data => $key[1]};
        }
        push @keyboard, [@row];
    }
    return \@keyboard;
}

=head2 merge_keyboards

Merges two keyboards into one.

=cut

sub merge_keyboards {
    my @keyboards = @_;
    my @merged_keyboard;
    while (scalar @keyboards) {
        my @keyboard = @{shift @keyboards};
        while (scalar @keyboard) {
            push @merged_keyboard, shift @keyboard;
        }
    }
    return \@merged_keyboard;
}
