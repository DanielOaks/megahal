package MegaHAL::Interface;
use Term::ANSIColor qw(colorstrip);
use Scalar::Util qw(weaken);
use MegaHAL::ACL;

sub new {
    my ($class, $source, $target) = @_;
    my $self = {
        'source' => $source,
        'fh'     => undef,
        'code'   => undef
    };
    if (ref $target eq 'CODE') {
        $self->{'code'} = $target;
    } elsif (ref $target eq 'GLOB' or UNIVERSAL::isa($target, 'IO::Handle')) {
        $self->{'fh'} = $target;
    }
    bless $self, $class;
    $self->{'source'} = $self->source() if not $self->{'source'};
    return $self;
}

sub cerr {
    my ($self) = @_;
    $self->{'errh'} = sub {
        $self->write("\cC5" . $_[0]);
    };
    weaken($::outh{ &::hout($self->{'errh'}) });
}

sub ecerr {
    my ($self) = @_;
    delete $self->{'errh'};
}

sub write {
    my $self = shift;
    my $str = join ' ', @_;
    $str = colorstrip($str);    #Get rid of existing Term::ANSIColor codes, because Shit Happens(tm)
    my %map = $self->colour();
    foreach (grep { $_ ne "\cC" } keys %map) {
        $str =~ s/($_)/ref $map{$_} eq 'CODE' ? $map{$_}->($1) : $map{$_}/eg;
    }
    $str =~ s/(\cC\d?\d?(?:,\d\d?)?)/ref $map{"\cC"} eq 'CODE' ? $map{"\cC"}->($1) : $map{"\cC"}/eg if defined $map{"\cC"};
    return $self->_write($str) if $self->can('_write');
    return $self->{'code'}->($str) if $self->{'code'};
    return print $self->{'fh'}, $str if $self->{'fh'};
    return print "[$$self{source}] $str\n";
}

sub type   {"UNKNOWN"}
sub source { $_[0]->{'source'} || "UNKNOWN" }
sub atype  {'user'}

sub acan {
    my ($self, $nodes, $cb) = @_;
    if ($self->atype() eq 'irc' && defined($self->{'server'})) {
        return $self->auth(
            sub {
                return 0 if not $_[0];
                my $nick = $_[0];
                my $res  = 0;
                foreach (@$nodes) {
                    if (MegaHAL::ACL::has_ircnode($self->{'server'}, $nick, $_->[0], $_->[1], $_->[2])) {
                        $res = 1;
                        last;
                    }
                }
                $cb->($res, $nick) if $cb;
                return wantarray ? ($res, $nick) : $res;
            }
        );
    } elsif ($self->atype() eq 'user') {
        return $self->auth(
            sub {
                return 0 if not $_[0];
                my $user = $_[0];
                my $res  = 0;
                foreach (@$nodes) {
                    if (MegaHAL::ACL::has_node($user, $_->[1], $_->[2])) {
                        $res = 1;
                        last;
                    }
                }
                $cb->($res, $user) if $cb;
                return wantarray ? ($res, $user) : $res;
            }
        );
    } elsif ($self->atype() eq 'always') {
        $cb->(1) if $cb;
        return 1;
    } else {
        return 0;
    }
}

sub colour {
    (   "\cB" => "",
        "\cC" => "",
        "\cU" => "",
        "\cR" => "",
        "\c_" => "",
        "\c]" => "",
        "\cO" => ""
    );
}

sub auth {
    my ($self, $cb) = @_;
    my $ret = $self->_auth($cb);
    if (defined($ret)) {
        return $cb->($ret) if $cb;
        return $ret;
    }
    return undef;
}

sub _auth {
    return 0;
}
1;
