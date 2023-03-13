# docker-adguardhome

## Flow of DNS query requests

```log
Adguardhome -> Unbound -> Stubby
```

## Possible combinations

### NOT ALLOWED

```log
AGH_ENABLED=0
UNBOUND_ENABLED=0
```

### Adguardhome ONLY

```log
AGH_ENABLED=1
UNBOUND_ENABLED=0
```

This is a default mode.

### Adguardhome + Unbound

```log
AGH_ENABLED=1
UNBOUND_ENABLED=1
STUBBY=0
```

```log
Adguardhome#53 -> Unbound#5053 -> ${UNBOUND_UPSTREAMS}
```

where `UNBOUND_UPSTREAMS` is `1.1.1.1@853#cloudflare-dns.com 1.0.0.1@853#cloudflare-dns.com` by default, but can be a list of different tls upstreams (space-separated).

If `UNBOUND_UPSTREAMS` is unset, unbound will not forward queries and run as a local recursive resolver.

### Adguardhome + Unbound + Stubby

```log
AGH_ENABLED=1
UNBOUND_ENABLED=1
STUBBY=1
```

```log
Adguardhome#53 -> Unbound#5053 -> Stubby#8053 -> ${STUBBY_UPSTREAMS}
```

where `STUBBY_UPSTREAMS` is a list of tls upstreams (space-separated), e.g. `1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com`.

### Unbound ONLY

```log
AGH_ENABLED=0
UNBOUND_ENABLED=1
STUBBY=0
```

```log
Unbound#53 -> ${UNBOUND_UPSTREAMS}
```

### Unbound + Stubby

```log
AGH_ENABLED=0
UNBOUND_ENABLED=1
STUBBY=1
```

```log
Unbound#53 -> Stubby#8053 -> ${STUBBY_UPSTREAMS}
```

## Benchmark

### Adguardhome + Unbound

```log
Adguardhome#53 -> Unbound#5053 -> ${UNBOUND_UPSTREAMS}
```

Adguardhome Upstreams:

- Unbound#5053

  Unbound Upstreams:

  - 1.1.1.1@853#cloudflare-dns.com
  - 1.0.0.1@853#cloudflare-dns.com

    Adguardhome Cache: 4194304 bytes

    |                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
    |  ----------------|-------|-------|-------|-------|-------|
    |    Cached Name   | 0.003 | 0.003 | 0.005 | 0.001 | 100.0 |
    |    Uncached Name | 0.003 | 0.089 | 0.213 | 0.075 | 100.0 |
    |    DotCom Lookup | 0.005 | 0.100 | 0.195 | 0.081 | 100.0 |

    Adguardhome Cache: Off

    |                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
    |  ----------------|-------|-------|-------|-------|-------|
    |    Cached Name   | 0.003 | 0.005 | 0.007 | 0.001 | 100.0 |
    |    Uncached Name | 0.003 | 0.095 | 0.325 | 0.081 | 100.0 |
    |    DotCom Lookup | 0.005 | 0.104 | 0.272 | 0.087 | 100.0 |

  Unbound Upstreams:
  
  - None (as a local recursive resolver)

    Adguardhome Cache: 4194304 bytes

    |                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
    |  ----------------|-------|-------|-------|-------|-------|
    |    Cached Name   | 0.003 | 0.003 | 0.005 | 0.000 | 100.0 |
    |    Uncached Name | 0.004 | 0.075 | 0.264 | 0.079 | 100.0 |
    |    DotCom Lookup | 0.005 | 0.063 | 0.197 | 0.073 | 100.0 |

    Adguardhome Cache: Off

    |                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
    |  ----------------|-------|-------|-------|-------|-------|
    |    Cached Name   | 0.003 | 0.005 | 0.008 | 0.001 | 100.0 |
    |    Uncached Name | 0.003 | 0.084 | 0.237 | 0.077 | 100.0 |
    |    DotCom Lookup | 0.006 | 0.103 | 0.266 | 0.082 | 100.0 |

> Cache should be better turned on even if one of upstreams has it.

> Unbound running as a local recursive resolver has an advantage for uncached/dotcom lookup.

Adguardhome Upstreams:

- 127.0.0.1:5053
- <tls://1dot1dot1dot1.cloudflare-dns.com>
- <https://cloudflare-dns.com/dns-query>

  Unbound Upstreams:

  - 1.1.1.1@853#cloudflare-dns.com
  - 1.0.0.1@853#cloudflare-dns.com

    |                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
    |  ----------------|-------|-------|-------|-------|-------|
    |    Cached Name   | 0.003 | 0.003 | 0.005 | 0.000 | 100.0 |
    |    Uncached Name | 0.004 | 0.090 | 0.261 | 0.075 | 100.0 |
    |    DotCom Lookup | 0.005 | 0.077 | 0.248 | 0.078 | 100.0 |

  Unbound Upstreams:
  
  - None (as a local recursive resolver)

    |                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
    |  ----------------|-------|-------|-------|-------|-------|
    |    Cached Name   | 0.003 | 0.004 | 0.007 | 0.001 | 100.0 |
    |    Uncached Name | 0.003 | 0.083 | 0.254 | 0.070 | 100.0 |
    |    DotCom Lookup | 0.006 | 0.063 | 0.189 | 0.063 | 100.0 |

> Using unbound along with other public DNS as Adguardhome upstreams is recommended.

### Adguardhome w/ or w/o Stubby

#### Adguardhome ONLY

Adguard Upstreams:

- <tls://1dot1dot1dot1.cloudflare-dns.com>
- <https://cloudflare-dns.com/dns-query>

|                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
|  ----------------|-------|-------|-------|-------|-------|
|    Cached Name   | 0.003 | 0.004 | 0.006 | 0.001 | 100.0 |
|    Uncached Name | 0.003 | 0.096 | 0.277 | 0.079 | 100.0 |
|    DotCom Lookup | 0.005 | 0.125 | 0.280 | 0.085 | 100.0 |

### Adguardhome + Stubby

```log
Adguardhome#53 -> Stubby#8053 -> ${STUBBY_UPSTREAMS}
```

Stubby Upstreams:

- 1.1.1.1#cloudflare-dns.com
- 1.0.0.1#cloudflare-dns.com

|                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
|  ----------------|-------|-------|-------|-------|-------|
|    Cached Name   | 0.003 | 0.004 | 0.006 | 0.001 | 100.0 |
|    Uncached Name | 0.003 | 0.128 | 0.374 | 0.100 | 100.0 |
|    DotCom Lookup | 0.017 | 0.221 | 0.429 | 0.125 | 100.0 |

>> There's no reason to use Stubby as an additional TLS forwarder.
