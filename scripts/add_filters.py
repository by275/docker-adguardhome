import sys
import logging
from getpass import getpass

import requests

logger = logging.getLogger()
logger.addHandler(logging.StreamHandler())
logger.setLevel("INFO")


if sys.version_info[:2] < (3, 6):
    logger.error("Try again with Python 3.6+")
    sys.exit(1)

#
# LOGIN
#

host = input("host: ").strip().rstrip("/") or sys.exit(1)
username = input("username: ").strip() or sys.exit(1)
password = getpass("password: ").strip() or sys.exit(1)

headers = {"User-Agent": "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:52.0) Gecko/20100101 Firefox/52.0"}

s = requests.Session()
s.headers.update(headers)
try:
    x = s.post(host + "/control/login", json={"name": username, "password": password})
    x.raise_for_status()
except Exception as e:
    logger.exception("Exception attempting login to '%s'", host)
    sys.exit(1)
logger.info("\nLogin Successful!\n")

#
# LISTUP URLS
#

burls = [
    # StevenBlack
    # from pi-hole basics - https://github.com/pi-hole/pi-hole/blob/e773e3302ca66a6d918a40c8a8c6282f223d4906/automated%20install/basic-install.sh#L1217
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
    # phishing.army
    "https://phishing.army/download/phishing_army_blocklist.txt",
    # motti/pihole-regex
    "https://raw.githubusercontent.com/mmotti/pihole-regex/master/regex.list",
]
# getting more from https://v.firebog.net/hosts/lists.php?type=nocross
burls_more = "https://v.firebog.net/hosts/lists.php?type=nocross"
try:
    for url in list(requests.get(burls_more, timeout=10).text.splitlines()):
        if url:
            burls.append(url)
    logger.info("%d blocklists ready!", len(burls))
except Exception as e:
    logger.exception("Exception while getting blocklist urls from '%s'", burls_more)
    sys.exit(1)

aurls = [
    "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt",
    "https://raw.githubusercontent.com/hl2guide/AdGuard-Home-Whitelist/main/whitelist.txt",
]
logger.info("%d allowlists ready!", len(aurls))

#
# ADD FILTERS
#

logger.info("\nAdding filter urls - blocklist")
for i, url in enumerate(burls):
    log_prefix = f"[{i+1:03d}/{len(burls):03d}]"
    try:
        params = {"url": url, "name": url, "whitelist": False}
        x = s.post(host + "/control/filtering/add_url", json=params)
        x.raise_for_status()
    except Exception:
        logger.exception("%s %s -- Exception while adding url to blocklist:", log_prefix, url)
    else:
        logger.info("%s %s -- %s", log_prefix, url, x.text.replace("--", "").replace(url, "").strip())

logger.info("\nAdding filter urls - allowlist")
for i, url in enumerate(aurls):
    log_prefix = f"[{i+1:03d}/{len(aurls):03d}]"
    try:
        params = {"url": url, "name": url, "whitelist": True}
        x = s.post(host + "/control/filtering/add_url", json=params)
        x.raise_for_status()
    except Exception:
        logger.exception("%s %s -- Exception while adding url to allowlist:", log_prefix, url)
    else:
        logger.info("%s %s -- %s", log_prefix, url, x.text.replace("--", "").replace(url, "").strip())
