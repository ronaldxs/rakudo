my class IO::Socket::INET does IO::Socket {
    my module PIO {
        constant PF_LOCAL       = 0;
        constant PF_UNIX        = 1;
        constant PF_INET        = 2;
        constant PF_INET6       = 3;
        constant PF_MAX         = 4;
        constant SOCK_PACKET    = 0;
        constant SOCK_STREAM    = 1;
        constant SOCK_DGRAM     = 2;
        constant SOCK_RAW       = 3;
        constant SOCK_RDM       = 4;
        constant SOCK_SEQPACKET = 5;
        constant SOCK_MAX       = 6;
        constant PROTO_TCP      = 6;
        constant PROTO_UDP      = 17;
    }

    has Str $.host;
    has Int $.port = 80;
    has Str $.localhost;
    has Int $.localport;
    has Int $.listen;
    has $.family = PIO::PF_INET;
    has $.proto = PIO::PROTO_TCP;
    has $.type = PIO::SOCK_STREAM;

    my sub v4-split($uri) {
        return $uri.split(':', 2);
    }

    my sub v6-split($uri) {
        my ($host, $port) = ($uri ~~ /^'[' (.+) ']' \: (\d+)$/)[0,1];
        return $host ?? ($host, $port) !! $uri;
    }

    method new (*%args is copy) {
        fail "Nothing given for new socket to connect or bind to" unless %args<host> || %args<listen>;

        if %args<host>  {
            my ($host, $port) = %args<family> && %args<family> == PIO::PF_INET6() 
                ?? v6-split(%args<host>)
                !! v4-split(%args<host>);
            if $port {
                %args<port> //= $port;
                %args<host> = $host;
            }
        }
        if %args<localhost> {
            my ($peer, $port) = %args<family> && %args<family> == PIO::PF_INET6() 
                ?? v6-split(%args<localhost>)
                !! v4-split(%args<localhost>);
            if $port {
                %args<localport> //= $port;
                %args<localhost> = $peer;
            }
        }

        #TODO: Learn what protocols map to which socket types and then determine which is needed.
        self.bless(*, |%args)!initialize()
    }
    
    method !initialize() {
        my $PIO := Q:PIR { %r = root_new ['parrot';'Socket'] };
        $PIO.socket($.family, $.type, $.proto);        
        
        #Quoting perl5's SIO::INET:
        #If Listen is defined then a listen socket is created, else if the socket type, 
        #which is derived from the protocol, is SOCK_STREAM then connect() is called.
        if $.listen || $.localhost || $.localport {
            my $addr := $PIO.sockaddr($.localhost || "0.0.0.0", $.localport || 0);
            $PIO.bind($addr);
        }

        if $.listen { 
            $PIO.listen($.listen);
        }
        elsif $.type == PIO::SOCK_STREAM {
            my $addr := $PIO.sockaddr($.host, $.port);
            $PIO.connect($addr);
        }
        
        nqp::bindattr(self, $?CLASS, '$!PIO', $PIO);
        self;
    }

    method get() {
        nqp::p6box_s(nqp::getattr(self, $?CLASS, '$!PIO').readline).chomp
    }

    method lines() {
        gather { take self.get() };
    }

    method accept() {
        return nqp::p6bool(nqp::getattr(self, $?CLASS, '$!PIO').accept());
    }

    method remote_address() {
        return nqp::p6box_s(nqp::getattr(self, $?CLASS, '$!PIO').remote_address());
    }

    method local_address() {
        return nqp::p6box_s(nqp::getattr(self, $?CLASS, '$!PIO').local_address());
    }
}
