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

### Adguardhome ONLY

Upstreams(with Parallel requests):

- <tls://1dot1dot1dot1.cloudflare-dns.com>
- <https://cloudflare-dns.com/dns-query>

Cache: 4194304 bytes

|                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
|  ----------------|-------|-------|-------|-------|-------|
|    Cached Name   | 0.001 | 0.001 | 0.003 | 0.000 |  93.2 |
|    Uncached Name | 0.001 | 0.076 | 0.238 | 0.061 |  87.8 |
|    DotCom Lookup | 0.007 | 0.092 | 0.199 | 0.072 |  83.3 |

### Adguardhome + Unbound

```log
Adguardhome#53 -> Unbound#5053 -> ${UNBOUND_UPSTREAMS}
```

Upstreams:

- 1.1.1.1@853#cloudflare-dns.com
- 1.0.0.1@853#cloudflare-dns.com

|                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
|  ----------------|-------|-------|-------|-------|-------|
|    Cached Name   | 0.001 | 0.001 | 0.002 | 0.000 |  90.9 |
|    Uncached Name | 0.001 | 0.078 | 0.236 | 0.063 |  85.0 |
|    DotCom Lookup | 0.008 | 0.059 | 0.191 | 0.056 |  79.4 |

Upstreams: None

|                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
|  ----------------|-------|-------|-------|-------|-------|
|    Cached Name   | 0.001 | 0.001 | 0.002 | 0.000 |  91.1 |
|    Uncached Name | 0.001 | 0.074 | 0.238 | 0.050 |  95.1 |
|    DotCom Lookup | 0.007 | 0.053 | 0.200 | 0.065 |  79.5 |

### Adguardhome + Unbound + Stubby

```log
Adguardhome#53 -> Unbound#5053 -> Stubby#8053 -> ${STUBBY_UPSTREAMS}
```

Upstreams:

- 1.1.1.1#cloudflare-dns.com
- 1.0.0.1#cloudflare-dns.com

|                  |  Min  |  Avg  |  Max  |Std.Dev|Reliab%|
|  ----------------|-------|-------|-------|-------|-------|
|    Cached Name   | 0.001 | 0.001 | 0.002 | 0.000 |  85.4 |
|    Uncached Name | 0.001 | 0.082 | 0.253 | 0.063 |  88.6 |
|    DotCom Lookup | 0.008 | 0.063 | 0.193 | 0.062 |  83.9 |
