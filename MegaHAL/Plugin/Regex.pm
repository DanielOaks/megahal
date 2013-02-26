package MegaHAL::Plugin::Regex;
use Safe;
use feature 'switch';

sub new {
    my ($class, $serv) = @_;
    my $self = { 'chans' => {}, 'lastmsg' => {} };
    $serv->reg_cb(
        'publicmsg' => sub {
            my ($this, $nick, $ircmsg) = @_;
            my ($modes, $nick, $ident) = $this->split_nick_mode($ircmsg->{'prefix'});
            my $command = $ircmsg->{'command'};
            my $chan    = $ircmsg->{'params'}->[0];
            my $message = $ircmsg->{'params'}->[1];
            my $mstr    = join '', keys %{$modes};
            return if $command ne 'PRIVMSG' or $this->is_my_nick($nick);
            if ($self->{'chans'}->{$chan}) {
                if ($message =~ /^ps\/.*\/.*\/[i]*$/) {
					my ($B, $C, $U, $O, $V) = ("\cB", "\cC", "\c_", "\cO", "\cV");
					$message =~ s/\\\\/\000/g;
					$message =~ s/\\\//\001/g;
					$message =~ /^p(s\/.*\/.*\/[i]*)$/;
					my $re=$1;
					$re=~s/\000/\\\\/g;
					$re=~s/\001/\\\//g;
					my $s=new Safe;
					$s->permit(qw(:base_core));
					if (not defined $self->{'lastmsg'}->{$chan}) {
						return;
					}
					${$s->varglob('msg')}=$self->{'lastmsg'}->{$chan}->[1];
					my $ret;
					eval {
						local $SIG{ALRM}=sub {die "Timeout.\n"};
						alarm 1;
						local $SIG{FPE}='IGNORE';
						$ret=$s->reval('local $_=$msg;$mtch='.$re.';return $_;');
						alarm 0;
					}
					if ($@) {
						$serv->msg($chan,"Error: ${C}5".$@);
					}elsif (${$s->varglob('mtch')}) {
						$serv->msg($chan,'<'.$self->{'lastmsg'}->{$chan}->[0].'> '.$ret);
					}else{
						$serv->msg($chan,$nick.': No match.');
					}
					return;
                }
            }
            $self->{'lastmsg'}->{$chan}=[$nick,$ircmsg];
        }
    );
    return bless $self, $class;
}

sub load {
    my ($self, $data) = @_;
    $self->{'chans'} = $data;
}

sub save {
    my ($self) = @_;
    return $self->{'chans'};
}
