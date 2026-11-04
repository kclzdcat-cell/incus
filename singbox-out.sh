#!/usr/bin/env bash
# LazyCat sing-box manager: self-contained installer (Linux / systemd).
# Embedded manager, default domains and Google rules; AI rules update remotely.
# LazyCat Sing-box：完整明文单文件安装器
# 上传本文件到 GitHub，下载后执行：sudo bash singbox-install.sh
# 前置依赖：Linux/systemd、Python 3.9+、curl、tar、iproute2。
# 本文件直接包含管理程序和默认规则，不含 Base64 或压缩编码载荷。
# 临时目录用于安装期间展开源码；退出后自动删除。
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo '请使用 sudo bash singbox-install.sh'; exit 1; }
command -v python3 >/dev/null || { echo '缺少 python3，请先安装 Python 3.9 或更高版本'; exit 1; }
command -v python3 >/dev/null || { echo '请先安装 Python 3.9 或更高版本'; exit 1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,9) else "需要 Python 3.9 或更高版本")'
umask 077
SINGBOX_STAGE=$(mktemp -d)
trap 'rm -rf -- "$SINGBOX_STAGE"' EXIT
python3 - "$SINGBOX_STAGE" <<'SINGBOX_EMBEDDED_PY'
import base64,gzip,json,pathlib,sys
payload = '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'
files=json.loads(gzip.decompress(base64.b64decode(payload)))
root=pathlib.Path(sys.argv[1])
for name in ('install.sh','singbox.py','defaults.json','google.srs'):
    (root/name).write_bytes(base64.b64decode(files[name]))
SINGBOX_EMBEDDED_PY

# ===== 默认家宽域名：可直接编辑下方 JSON =====
cat > "$SINGBOX_STAGE/defaults.json" <<'SINGBOX_DEFAULT_DOMAINS'
{
  "IP检测": [
    "iplark.com",
    "ping0.cc",
    "ipinfo.io",
    "ip2location.com",
    "ip2location.io",
    "ipdb.io",
    "ipip.net",
    "ip.sb",
    "ip.skk.moe",
    "ipapi.co",
    "ip-api.com",
    "ipapi.is",
    "ipapi.com",
    "ipwho.is",
    "ipwhois.io",
    "iplocation.net",
    "ipaddress.com",
    "ipgeolocation.io",
    "ipdata.co",
    "db-ip.com",
    "maxmind.com",
    "geoip.com",
    "ipify.org",
    "ifconfig.me",
    "ifconfig.co",
    "icanhazip.com",
    "ident.me",
    "checkip.amazonaws.com",
    "api.myip.com",
    "myip.com",
    "whatismyip.com",
    "whatismyipaddress.com",
    "browserleaks.com",
    "ipleak.net",
    "dnsleaktest.com",
    "scamalytics.com",
    "ipqualityscore.com",
    "ip138.com",
    "cip.cc"
  ],
  "流媒体与社交": [
    "netflix.com",
    "netflix.net",
    "nflxvideo.net",
    "nflximg.net",
    "nflximg.com",
    "nflxso.net",
    "nflxext.com",
    "disneyplus.com",
    "disney-plus.net",
    "dssott.com",
    "bamgrid.com",
    "hulu.com",
    "huluim.com",
    "hulustream.com",
    "primevideo.com",
    "aiv-cdn.net",
    "aiv-delivery.net",
    "amazonvideo.com",
    "max.com",
    "hbomax.com",
    "hbo.com",
    "hbonow.com",
    "hbomaxcdn.com",
    "paramountplus.com",
    "pplusstatic.com",
    "peacocktv.com",
    "peacocktv.net",
    "crunchyroll.com",
    "vrv.co",
    "spotify.com",
    "scdn.co",
    "spotifycdn.com",
    "spotifycdn.net",
    "twitch.tv",
    "ttvnw.net",
    "jtvnw.net",
    "twitchcdn.net",
    "kick.com",
    "tiktok.com",
    "tiktokv.com",
    "tiktokcdn.com",
    "tiktokcdn-us.com",
    "tiktokv.us",
    "musical.ly",
    "byteoversea.com",
    "ibytedtos.com",
    "instagram.com",
    "cdninstagram.com",
    "facebook.com",
    "fbcdn.net",
    "fbsbx.com",
    "threads.net",
    "threads.com"
  ],
  "Telegram": [
    "cdn-telegram.org",
    "comments.app",
    "t.me",
    "tdesktop.com",
    "telegra.ph",
    "telegram-cdn.org",
    "telegram.dog",
    "telegram.me",
    "telegram.org",
    "telegram.space",
    "telesco.pe",
    "tg.dev",
    "tx.me",
    "usercontent.dev"
  ],
  "Discord": [
    "dis.gd",
    "discord.co",
    "discord.com",
    "discord.design",
    "discord.dev",
    "discord.gg",
    "discord.gift",
    "discord.gifts",
    "discord.media",
    "discord.new",
    "discord.store",
    "discord.tools",
    "discord-activities.com",
    "discordactivities.com",
    "discordapp.com",
    "discordapp.net",
    "discordmerch.com",
    "discordpartygames.com",
    "discordsays.com",
    "discordstatus.com",
    "discordcdn.com",
    "discord-attachments-uploads-prd.storage.googleapis.com",
    "hammerandchisel.ssl.zendesk.com"
  ],
  "X/Twitter": [
    "x.com",
    "twitter.com",
    "t.co",
    "twimg.com",
    "cms-twdigitalassets.com",
    "periscope.tv",
    "pscp.tv",
    "tweetdeck.com",
    "twitpic.com",
    "twitter.biz",
    "twitter.jp",
    "twitter.map.fastly.net",
    "twittercommunity.com",
    "twitterinc.com",
    "twitteroauth.com",
    "twitterstat.us",
    "twtrdns.net",
    "twttr.com",
    "twttr.net",
    "twvid.com"
  ],
  "Cloudflare": [
    "cloudflare.com",
    "cloudflare.net",
    "cloudflare-dns.com",
    "cloudflare-ech.com",
    "cloudflare-esni.com",
    "cloudflare-quic.com",
    "cloudflare.app",
    "cloudflare.dev",
    "cloudflare.tv",
    "cloudflareaccess.com",
    "cloudflareapps.com",
    "cloudflarebrowser.com",
    "cloudflarechallenge.com",
    "cloudflareclient.com",
    "cloudflareinsights.com",
    "cloudflareportal.com",
    "cloudflarepreview.com",
    "cloudflareregistrar.com",
    "cloudflareresearch.com",
    "cloudflareresolve.com",
    "cloudflaressl.com",
    "cloudflarestatus.com",
    "cloudflarestorage.com",
    "cloudflarestream.com",
    "cloudflaresupport.com",
    "cloudflaretest.com",
    "cloudflarewarp.com",
    "cloudflareworkers.com",
    "argotunnel.com",
    "cfargotunnel.com",
    "trycloudflare.com",
    "workers.dev",
    "pages.dev",
    "r2.dev",
    "imagedelivery.net",
    "videodelivery.net",
    "one.one.one",
    "warp.plus"
  ]
}
SINGBOX_DEFAULT_DOMAINS

# ===== Google 本地规则：明文 JSON，选装代理3时使用 =====
cat > "$SINGBOX_STAGE/google.json" <<'SINGBOX_GOOGLE_RULES'
{
  "version": 1,
  "rules": [
    {
      "domain": [
        "alt1-mtalk.google.com",
        "alt2-mtalk.google.com",
        "alt3-mtalk.google.com",
        "alt4-mtalk.google.com",
        "alt5-mtalk.google.com",
        "alt6-mtalk.google.com",
        "analytics.google.com",
        "apps5.oingo.com",
        "avail.googleflights.net",
        "beacons.gcp.gvt2.com",
        "beacons.gvt2.com",
        "beacons2.gvt2.com",
        "beacons3.gvt2.com",
        "c.admob.com",
        "c.android.clients.google.com",
        "c.pki.goog",
        "cache-management-prod.google.com",
        "cache.pack.google.com",
        "checkin.gstatic.com",
        "clickserve.cc-dt.com",
        "clickserve.dartsearch.net",
        "clickserver.googleads.com",
        "clientservices.googleapis.com",
        "cn.widevine.com",
        "connectivitycheck.gstatic.com",
        "crashlyticsreports-pa.googleapis.com",
        "crl.pki.goog",
        "crls.pki.goog",
        "csi.gstatic.com",
        "dartsearch-cn.net",
        "dg-meta.video.google.com",
        "dl.google.com",
        "dl.l.google.com",
        "download.mlcc.google.com",
        "download.tensorflow.google.com",
        "firebase-settings.crashlytics.com",
        "firebaselogging-pa.googleapis.com",
        "firebaselogging.googleapis.com",
        "fontfiles.googleapis.com",
        "fonts.googleapis.com",
        "fonts.gstatic.com",
        "g0.gstatic.com",
        "g1.gstatic.com",
        "g2.gstatic.com",
        "g3.gstatic.com",
        "gongyichuangyi.net",
        "google-ohttp-relay-safebrowsing.fastly-edge.com",
        "googleapis-cn.com",
        "googleapps-cn.com",
        "googleflights-cn.net",
        "gstatic-cn.com",
        "gstaticadssl.l.google.com",
        "gtm.oasisfeng.com",
        "i.pki.goog",
        "imasdk.googleapis.com",
        "mtalk.google.com",
        "o.pki.goog",
        "ocsp.pki.goog",
        "pagead-googlehosted.l.google.com",
        "performanceparameters.googleapis.com",
        "pki-goog.l.google.com",
        "prod-controlbe.floonet.goog",
        "prod-databe.floonet.goog",
        "prod.databe.floonet.goog",
        "qiao-cn.com",
        "qpx.googleflights.net",
        "recaptcha-cn.net",
        "recaptcha.net",
        "redirector.bdn.dev",
        "redirector.c.chat.google.com",
        "redirector.c.mail.google.com",
        "redirector.c.pack.google.com",
        "redirector.c.play.google.com",
        "redirector.c.youtubeeducation.com",
        "redirector.gcpcdn.gvt1.com",
        "redirector.gvt1.com",
        "redirector.offline-maps.gvt1.com",
        "redirector.snap.gvt1.com",
        "redirector.xn--ngstr-lra8j.com",
        "safebrowsing-cache.google.com",
        "safebrowsing.googleapis.com",
        "service.urchin.com",
        "ssl-google-analytics.l.google.com",
        "ssl.gstatic.com",
        "staging-controlbe.floonet.goog",
        "staging-databe.floonet.goog",
        "staging.databe.floonet.goog",
        "tac.googleapis.com",
        "tools.google.com",
        "update.crashlytics.com",
        "update.googleapis.com",
        "wear.googleapis.com",
        "www-google-analytics.l.google.com",
        "www-googletagmanager.l.google.com",
        "www.destinationurl.com",
        "www.gstatic.com",
        "www.pxcc.com",
        "www.recaptcha-cn.net",
        "www.recaptcha.net"
      ],
      "domain_suffix": [
        ".android",
        ".chrome",
        ".dclk",
        ".gbiz",
        ".gle",
        ".gmail",
        ".goog",
        ".google",
        ".guge",
        ".hangout",
        ".nexus",
        ".xn--flw351e",
        ".xn--qcka1pmc",
        ".youtube",
        "0emm.com",
        "1e100.net",
        "1ucrs.com",
        "265.com",
        "2mdn-cn.net",
        "2mdn.net",
        "466453.com",
        "actifio.com",
        "adgoogle.net",
        "admeld.com",
        "admob-cn.com",
        "admob.com",
        "ads.youtube.com",
        "adsense.com",
        "adsensecustomsearchads.com",
        "adsenseformobileapps.com",
        "adservice.google.com",
        "adtrafficquality.google",
        "advertisercommunity.com",
        "advertiserscommunity.com",
        "adwords-community.com",
        "adwords.com",
        "adwordsexpress.com",
        "ai.studio",
        "analytics-alv.google.com",
        "android.com",
        "androidify.com",
        "angulardart.org",
        "api.ai",
        "apigee.com",
        "app-ads-services.com",
        "app-analytics-services-att.com",
        "app-analytics-services.com",
        "app-measurement-cn.com",
        "app-measurement.com",
        "appbridge.ca",
        "appbridge.io",
        "appbridge.it",
        "appspot.com",
        "apture.com",
        "area120.com",
        "asp-cc.com",
        "autodraw.com",
        "bandpage.com",
        "baselinestudy.com",
        "baselinestudy.org",
        "bazel.build",
        "bdn.dev",
        "beatthatquote.com",
        "blink.org",
        "blogblog.com",
        "blogger.com",
        "blogspot.ae",
        "blogspot.al",
        "blogspot.am",
        "blogspot.ba",
        "blogspot.be",
        "blogspot.bg",
        "blogspot.bj",
        "blogspot.ca",
        "blogspot.cf",
        "blogspot.ch",
        "blogspot.cl",
        "blogspot.co.at",
        "blogspot.co.id",
        "blogspot.co.il",
        "blogspot.co.ke",
        "blogspot.co.nz",
        "blogspot.co.uk",
        "blogspot.co.za",
        "blogspot.com",
        "blogspot.com.ar",
        "blogspot.com.au",
        "blogspot.com.br",
        "blogspot.com.by",
        "blogspot.com.co",
        "blogspot.com.cy",
        "blogspot.com.ee",
        "blogspot.com.eg",
        "blogspot.com.es",
        "blogspot.com.mt",
        "blogspot.com.ng",
        "blogspot.com.tr",
        "blogspot.com.uy",
        "blogspot.cv",
        "blogspot.cz",
        "blogspot.de",
        "blogspot.dk",
        "blogspot.fi",
        "blogspot.fr",
        "blogspot.gr",
        "blogspot.hk",
        "blogspot.hr",
        "blogspot.hu",
        "blogspot.ie",
        "blogspot.in",
        "blogspot.is",
        "blogspot.it",
        "blogspot.jp",
        "blogspot.kr",
        "blogspot.li",
        "blogspot.lt",
        "blogspot.lu",
        "blogspot.md",
        "blogspot.mk",
        "blogspot.mx",
        "blogspot.my",
        "blogspot.nl",
        "blogspot.no",
        "blogspot.pe",
        "blogspot.pt",
        "blogspot.qa",
        "blogspot.re",
        "blogspot.ro",
        "blogspot.rs",
        "blogspot.ru",
        "blogspot.se",
        "blogspot.sg",
        "blogspot.si",
        "blogspot.sk",
        "blogspot.sn",
        "blogspot.td",
        "blogspot.tw",
        "blogspot.ug",
        "blogspot.vn",
        "brocaproject.com",
        "brotli.org",
        "bumpshare.com",
        "bumptop.ca",
        "bumptop.com",
        "bumptop.net",
        "bumptop.org",
        "bumptunes.com",
        "campuslondon.com",
        "certificate-transparency.org",
        "charlestonroadregistry.com",
        "chrome.com",
        "chromebook.com",
        "chromecast.com",
        "chromeos.dev",
        "chromestatus.com",
        "chromium.org",
        "chronicle.security",
        "chroniclesec.com",
        "cloudburstresearch.com",
        "cloudfunctions.net",
        "cloudproxy.app",
        "cloudrobotics.com",
        "cobrasearch.com",
        "codespot.com",
        "conscrypt.com",
        "conscrypt.org",
        "cookiechoices.org",
        "coova.com",
        "coova.net",
        "coova.org",
        "crashlytics.com",
        "crossmediapanel.com",
        "crr.com",
        "cs4hs.com",
        "dart.dev",
        "dartlang.org",
        "dartpad.dev",
        "dartsearch.net",
        "dataliberation.org",
        "debug.com",
        "debugproject.com",
        "deepmind.com",
        "deps.dev",
        "deps.info",
        "devsitetest.how",
        "dialogflow.com",
        "digitalassetlinks.org",
        "docs.new",
        "doubleclick-cn.net",
        "doubleclick.cn",
        "doubleclick.com",
        "doubleclick.net",
        "episodic.com",
        "fastlane.ci",
        "fastlane.tools",
        "fcmatch.google.com",
        "feedburner.com",
        "fflick.com",
        "financeleadsonline.com",
        "firebase.com",
        "firebase.dev",
        "firebase.io",
        "firebaseapp.com",
        "firebaseio.com",
        "fitbit.com",
        "flutter.dev",
        "flutterapp.com",
        "foofle.com",
        "froogle.com",
        "fuchsia.dev",
        "g-tun.com",
        "g.cn",
        "g.co",
        "g.dev",
        "g.page",
        "gateway.dev",
        "gcr.io",
        "gerritcodereview.com",
        "get.app",
        "get.dev",
        "get.how",
        "get.new",
        "get.page",
        "get.rsvp",
        "getbumptop.com",
        "ggoogle.com",
        "ggpht.cn",
        "ggpht.com",
        "gipscorp.com",
        "gkecnapps.cn",
        "globaledu.org",
        "gmail.com",
        "gmodules.com",
        "go-lang.com",
        "go-lang.net",
        "go-lang.org",
        "go.dev",
        "godoc.org",
        "gogle.com",
        "gogole.com",
        "golang.com",
        "golang.net",
        "golang.org",
        "gonglchuangl.net",
        "goo.gl",
        "googel.com",
        "googil.com",
        "googl.com",
        "google-access.net",
        "google-analytics-cn.com",
        "google-analytics.com",
        "google-syndication.com",
        "google.ad",
        "google.ae",
        "google.al",
        "google.am",
        "google.as",
        "google.at",
        "google.az",
        "google.ba",
        "google.be",
        "google.berlin",
        "google.bf",
        "google.bg",
        "google.bi",
        "google.bj",
        "google.bs",
        "google.bt",
        "google.by",
        "google.ca",
        "google.cat",
        "google.cd",
        "google.cf",
        "google.cg",
        "google.ch",
        "google.ci",
        "google.cl",
        "google.cm",
        "google.cn",
        "google.co",
        "google.co.ao",
        "google.co.bw",
        "google.co.ck",
        "google.co.cr",
        "google.co.id",
        "google.co.il",
        "google.co.in",
        "google.co.jp",
        "google.co.ke",
        "google.co.kr",
        "google.co.ls",
        "google.co.ma",
        "google.co.mz",
        "google.co.nz",
        "google.co.th",
        "google.co.tz",
        "google.co.ug",
        "google.co.uk",
        "google.co.uz",
        "google.co.ve",
        "google.co.vi",
        "google.co.za",
        "google.co.zm",
        "google.co.zw",
        "google.com",
        "google.com.af",
        "google.com.ag",
        "google.com.ai",
        "google.com.ar",
        "google.com.au",
        "google.com.bd",
        "google.com.bh",
        "google.com.bn",
        "google.com.bo",
        "google.com.br",
        "google.com.bz",
        "google.com.co",
        "google.com.cu",
        "google.com.cy",
        "google.com.do",
        "google.com.ec",
        "google.com.eg",
        "google.com.et",
        "google.com.fj",
        "google.com.gh",
        "google.com.gi",
        "google.com.gt",
        "google.com.hk",
        "google.com.jm",
        "google.com.kh",
        "google.com.kw",
        "google.com.lb",
        "google.com.ly",
        "google.com.mm",
        "google.com.mt",
        "google.com.mx",
        "google.com.my",
        "google.com.na",
        "google.com.ng",
        "google.com.ni",
        "google.com.np",
        "google.com.om",
        "google.com.pa",
        "google.com.pe",
        "google.com.pg",
        "google.com.ph",
        "google.com.pk",
        "google.com.pr",
        "google.com.py",
        "google.com.qa",
        "google.com.sa",
        "google.com.sb",
        "google.com.sg",
        "google.com.sl",
        "google.com.sv",
        "google.com.tj",
        "google.com.tr",
        "google.com.tw",
        "google.com.ua",
        "google.com.uy",
        "google.com.vc",
        "google.com.vn",
        "google.cv",
        "google.cz",
        "google.de",
        "google.dev",
        "google.dj",
        "google.dk",
        "google.dm",
        "google.dz",
        "google.ee",
        "google.es",
        "google.fi",
        "google.fm",
        "google.fr",
        "google.ga",
        "google.ge",
        "google.gg",
        "google.gl",
        "google.gm",
        "google.gr",
        "google.gy",
        "google.hn",
        "google.hr",
        "google.ht",
        "google.hu",
        "google.ie",
        "google.im",
        "google.iq",
        "google.is",
        "google.it",
        "google.je",
        "google.jo",
        "google.kg",
        "google.ki",
        "google.kz",
        "google.la",
        "google.li",
        "google.lk",
        "google.lt",
        "google.lu",
        "google.lv",
        "google.md",
        "google.me",
        "google.mg",
        "google.mk",
        "google.ml",
        "google.mn",
        "google.ms",
        "google.mu",
        "google.mv",
        "google.mw",
        "google.ne",
        "google.net",
        "google.nl",
        "google.no",
        "google.nr",
        "google.nu",
        "google.org",
        "google.pl",
        "google.pn",
        "google.ps",
        "google.pt",
        "google.ro",
        "google.rs",
        "google.ru",
        "google.rw",
        "google.sc",
        "google.se",
        "google.sh",
        "google.si",
        "google.sk",
        "google.sm",
        "google.sn",
        "google.so",
        "google.sr",
        "google.st",
        "google.td",
        "google.tg",
        "google.tl",
        "google.tm",
        "google.tn",
        "google.to",
        "google.tt",
        "google.ventures",
        "google.vg",
        "google.vu",
        "google.ws",
        "googleacquisitionmigration.com",
        "googleadapis.com",
        "googleadapis.l.google.com",
        "googleads-cn.com",
        "googleads.com",
        "googleadservices-cn.com",
        "googleadservices.com",
        "googleadsserving.cn",
        "googleanalytics.com",
        "googleapis.cn",
        "googleapis.com",
        "googleapps.com",
        "googlearth.com",
        "googleblog.com",
        "googlebot.com",
        "googlecapital.com",
        "googlecert.net",
        "googlecnapps.cn",
        "googlecode.com",
        "googlecommerce.com",
        "googlecompare.co.uk",
        "googledanmark.com",
        "googledomains.com",
        "googledrive.com",
        "googlee.com",
        "googleearth.com",
        "googlefiber.com",
        "googlefiber.net",
        "googlefinland.com",
        "googlemail.com",
        "googlemaps.com",
        "googleoptimize-cn.com",
        "googleoptimize.com",
        "googlepagecreator.com",
        "googlephotos.com",
        "googleplay.com",
        "googleplus.com",
        "googlesource.com",
        "googlestore.com",
        "googlesverige.com",
        "googlesyndication-cn.com",
        "googlesyndication.com",
        "googletagmanager-cn.com",
        "googletagmanager.com",
        "googletagservices-cn.com",
        "googletagservices.com",
        "googletraveladservices-cn.com",
        "googletraveladservices.com",
        "googleusercontent.com",
        "googlevads-cn.com",
        "googleventures.com",
        "googlevideo.com",
        "googlezip.net",
        "googlr.com",
        "goolge.com",
        "gooogle.com",
        "gridaware.app",
        "gsrc.io",
        "gstatic.cn",
        "gstatic.com",
        "gstaticcnapps.cn",
        "gsuite.com",
        "gvt0.com",
        "gvt1-cn.com",
        "gvt1.com",
        "gvt2-cn.com",
        "gvt2.com",
        "gvt3.com",
        "gvt5.com",
        "gvt6.com",
        "gvt7.com",
        "gvt9.com",
        "haplorrhini.com",
        "hdrplusdata.org",
        "hey.boo",
        "hindiweb.com",
        "howtogetmo.co.uk",
        "html5rocks.com",
        "hwgo.com",
        "iam.soy",
        "iamremarkable.org",
        "idx.dev",
        "igoogle.com",
        "impermium.com",
        "itasoftware.com",
        "j2objc.org",
        "jibemobile.com",
        "kaggle.com",
        "kaggle.io",
        "kaggle.net",
        "kaggleusercontent.com",
        "keyhole.com",
        "keytransparency.com",
        "keytransparency.foo",
        "keytransparency.org",
        "lanternal.com",
        "like.com",
        "madewithcode.com",
        "mail-ads.google.com",
        "marketingplatform.google.com",
        "material.io",
        "mdialog.com",
        "meet.new",
        "mfg-inspector.com",
        "mobileads.google.com",
        "mobileview.page",
        "moodstocks.com",
        "near.by",
        "nest.com",
        "new.day",
        "nomulus.foo",
        "oauthz.com",
        "on.here",
        "on2.com",
        "onefifteen.net",
        "onefifteen.org",
        "oneworldmanystories.com",
        "opensourceinsight.dev",
        "opensourceinsights.dev",
        "openthread.io",
        "openweave.io",
        "openxla.org",
        "orbitera.com",
        "page.link",
        "pagead.l.google.com",
        "pagespeedmobilizer.com",
        "pageview.mobi",
        "panoramio.com",
        "partnerad.l.google.com",
        "partylikeits1986.org",
        "paxlicense.org",
        "picasa.com",
        "picasaweb.com",
        "picasaweb.net",
        "picasaweb.org",
        "picnik.com",
        "pittpatt.com",
        "pixate.com",
        "polymer-project.org",
        "polymerproject.org",
        "postini.com",
        "privacysandbox.com",
        "projectara.com",
        "projectbaseline.com",
        "pub.dev",
        "publishproxy.com",
        "questvisual.com",
        "quickoffice.com",
        "quiksee.com",
        "revolv.com",
        "ridepenguin.com",
        "run.app",
        "savethedate.foo",
        "saynow.com",
        "schemer.com",
        "screenwisetrends.com",
        "screenwisetrendspanel.com",
        "sheets.new",
        "slides.new",
        "snapseed.com",
        "solveforx.com",
        "stadia.dev",
        "stcroixmosquito.com",
        "stcroixmosquitoproject.com",
        "studywatchbyverily.com",
        "studywatchbyverily.org",
        "stxmosquito.com",
        "stxmosquitoproject.com",
        "stxmosquitoproject.net",
        "stxmosquitoproject.org",
        "synergyse.com",
        "tenor.com",
        "tensorflow.org",
        "tfhub.dev",
        "thecleversense.com",
        "thegooglestore.com",
        "thinkquarterly.co.uk",
        "thinkquarterly.com",
        "thinkwithgoogle.com",
        "tiltbrush.com",
        "txcloud.net",
        "txvia.com",
        "unfiltered.news",
        "urchin.com",
        "useplannr.com",
        "usvimosquito.com",
        "usvimosquitoproject.com",
        "v8.dev",
        "v8project.org",
        "velostrata.com",
        "verilylifesciences.com",
        "verilystudyhub.com",
        "verilystudywatch.com",
        "verilystudywatch.org",
        "wallet.com",
        "waze.com",
        "web.app",
        "web.dev",
        "webappfieldguide.com",
        "webmproject.org",
        "webpkgcache.com",
        "webrtc.org",
        "weltweitwachsen.de",
        "whatbrowser.org",
        "whats.new",
        "widevine.com",
        "withgoogle.com",
        "withyoutube.com",
        "womenwill.com",
        "womenwill.com.br",
        "womenwill.id",
        "womenwill.in",
        "womenwill.mx",
        "x.company",
        "x.team",
        "xn--9kr7l.com",
        "xn--9trs65b.com",
        "xn--flw351e.com",
        "xn--ggle-55da.com",
        "xn--gogl-0nd52e.com",
        "xn--gogl-1nd42e.com",
        "xn--ngstr-lra8j.com",
        "xn--p8j9a0d9c9a.xn--q9jyb4c",
        "xplr.co",
        "youtu.be",
        "youtube-nocookie.com",
        "youtube.ae",
        "youtube.al",
        "youtube.am",
        "youtube.at",
        "youtube.az",
        "youtube.ba",
        "youtube.be",
        "youtube.bg",
        "youtube.bh",
        "youtube.bo",
        "youtube.by",
        "youtube.ca",
        "youtube.cat",
        "youtube.ch",
        "youtube.cl",
        "youtube.co",
        "youtube.co.ae",
        "youtube.co.at",
        "youtube.co.cr",
        "youtube.co.hu",
        "youtube.co.id",
        "youtube.co.il",
        "youtube.co.in",
        "youtube.co.jp",
        "youtube.co.ke",
        "youtube.co.kr",
        "youtube.co.ma",
        "youtube.co.nz",
        "youtube.co.th",
        "youtube.co.tz",
        "youtube.co.ug",
        "youtube.co.uk",
        "youtube.co.ve",
        "youtube.co.za",
        "youtube.co.zw",
        "youtube.com",
        "youtube.com.ar",
        "youtube.com.au",
        "youtube.com.az",
        "youtube.com.bd",
        "youtube.com.bh",
        "youtube.com.bo",
        "youtube.com.br",
        "youtube.com.by",
        "youtube.com.co",
        "youtube.com.do",
        "youtube.com.ec",
        "youtube.com.ee",
        "youtube.com.eg",
        "youtube.com.es",
        "youtube.com.gh",
        "youtube.com.gr",
        "youtube.com.gt",
        "youtube.com.hk",
        "youtube.com.hn",
        "youtube.com.hr",
        "youtube.com.jm",
        "youtube.com.jo",
        "youtube.com.kw",
        "youtube.com.lb",
        "youtube.com.lv",
        "youtube.com.ly",
        "youtube.com.mk",
        "youtube.com.mt",
        "youtube.com.mx",
        "youtube.com.my",
        "youtube.com.ng",
        "youtube.com.ni",
        "youtube.com.om",
        "youtube.com.pa",
        "youtube.com.pe",
        "youtube.com.ph",
        "youtube.com.pk",
        "youtube.com.pt",
        "youtube.com.py",
        "youtube.com.qa",
        "youtube.com.ro",
        "youtube.com.sa",
        "youtube.com.sg",
        "youtube.com.sv",
        "youtube.com.tn",
        "youtube.com.tr",
        "youtube.com.tw",
        "youtube.com.ua",
        "youtube.com.uy",
        "youtube.com.ve",
        "youtube.cr",
        "youtube.cz",
        "youtube.de",
        "youtube.dk",
        "youtube.ee",
        "youtube.es",
        "youtube.fi",
        "youtube.fr",
        "youtube.ge",
        "youtube.gr",
        "youtube.gt",
        "youtube.hk",
        "youtube.hr",
        "youtube.hu",
        "youtube.ie",
        "youtube.in",
        "youtube.iq",
        "youtube.is",
        "youtube.it",
        "youtube.jo",
        "youtube.jp",
        "youtube.kr",
        "youtube.kz",
        "youtube.la",
        "youtube.lk",
        "youtube.lt",
        "youtube.lu",
        "youtube.lv",
        "youtube.ly",
        "youtube.ma",
        "youtube.md",
        "youtube.me",
        "youtube.mk",
        "youtube.mn",
        "youtube.mx",
        "youtube.my",
        "youtube.ng",
        "youtube.ni",
        "youtube.nl",
        "youtube.no",
        "youtube.pa",
        "youtube.pe",
        "youtube.ph",
        "youtube.pk",
        "youtube.pl",
        "youtube.pr",
        "youtube.pt",
        "youtube.qa",
        "youtube.ro",
        "youtube.rs",
        "youtube.ru",
        "youtube.sa",
        "youtube.se",
        "youtube.sg",
        "youtube.si",
        "youtube.sk",
        "youtube.sn",
        "youtube.soy",
        "youtube.sv",
        "youtube.tn",
        "youtube.tv",
        "youtube.ua",
        "youtube.ug",
        "youtube.uy",
        "youtube.vn",
        "youtubeeducation.com",
        "youtubefanfest.com",
        "youtubegaming.com",
        "youtubego.co.id",
        "youtubego.co.in",
        "youtubego.com",
        "youtubego.com.br",
        "youtubego.id",
        "youtubego.in",
        "youtubekids.com",
        "youtubemobilesupport.com",
        "yt.be",
        "ytimg.com",
        "zukunftswerkstatt.de"
      ],
      "domain_regex": [
        "^r+[0-9]+(---|\\.)sn-(2x3|ni5|j5o)\\w{5}\\.googlevideo\\.com$",
        "^r+[0-9]+(---|\\.)sn-(2x3|ni5|j5o)\\w{5}\\.xn--ngstr-lra8j\\.com$"
      ]
    }
  ]
}
SINGBOX_GOOGLE_RULES

# ===== 管理程序：配置生成、菜单、备份与回滚 =====
cat > "$SINGBOX_STAGE/singbox.py" <<'SINGBOX_MANAGER_PY'
#!/usr/bin/env python3
"""Linux/systemd sing-box 1.12.15 whitelist manager."""
import urllib.request
import os, sys, json, subprocess, pathlib, tempfile, time, fcntl, re, ipaddress, uuid, getpass, shutil
BASE=pathlib.Path('/etc/sing-box')
CONFIG=BASE/'config.json'
BIN='/usr/local/bin/sing-box'

def run(*args, check=True):
    return subprocess.run(args, check=check)

def domain(value):
    value=value.strip().lower().rstrip('.')
    if value.startswith('*.'): value=value[2:]
    value=value.encode('idna').decode('ascii')
    try: ipaddress.ip_address(value)
    except ValueError: pass
    else: raise ValueError('请输入域名，不是 IP')
    if len(value)>253 or '.' not in value or any(not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', x) for x in value.split('.')):
        raise ValueError('域名格式错误，请勿包含协议、端口或路径')
    return value

def atomic(path, data):
    fd,name=tempfile.mkstemp(dir=path.parent, prefix='.singbox-')
    try:
        with os.fdopen(fd,'wb') as f:
            f.write(data); f.flush(); os.fsync(f.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name): os.unlink(name)

def encode(c): return (json.dumps(c,ensure_ascii=False,indent=2)+'\n').encode()

def active():
    return subprocess.run(['systemctl','is-active','--quiet','sing-box']).returncode==0

def apply(c):
    candidate=BASE/'candidate.json'
    atomic(candidate,encode(c))
    try:
        run(BIN,'check','-c',str(candidate))
        old=CONFIG.read_bytes() if CONFIG.exists() else None
        if old: atomic(BASE/('backup-'+str(time.time_ns())+'.json'),old)
        atomic(CONFIG,candidate.read_bytes())
        try:
            run('systemctl','restart','sing-box','keep-alive')
            for _ in range(5):
                time.sleep(1)
                if not active(): raise RuntimeError('服务启动失败')
        except BaseException:
            if old:
                atomic(CONFIG,old)
                run('systemctl','restart','sing-box','keep-alive',check=False)
                print('已恢复旧配置；请检查服务状态。')
            else:
                run('systemctl','stop','sing-box','keep-alive',check=False)
            raise
    finally:
        candidate.unlink(missing_ok=True)

def ask(label, default=''):
    v=input(label+(f' [{default}]' if default else '')+': ').strip() or default
    if not v: raise ValueError('不能为空')
    return v

def node(tag,label):
    print('\n设置'+label+'：1 SOCKS5 / 2 VLESS TCP / 3 Shadowsocks / 4 VLESS Reality')
    kind=ask('协议序号')
    if kind not in ('1','2','3','4'): raise ValueError('无效协议')
    host=ask('服务器 IP 或域名').strip('[]')
    try: ipaddress.ip_address(host)
    except ValueError: host=domain(host)
    port=int(ask('端口'))
    if not 1<=port<=65535: raise ValueError('端口范围错误')
    o={'type':{'1':'socks','2':'vless','3':'shadowsocks','4':'vless'}[kind], 'tag':tag,'server':host,'server_port':port,'domain_resolver':'bootstrap'}
    if kind=='1':
        o.update(version='5',username=input('用户名（可空）: ').strip(),password=getpass.getpass('密码（可空）: '))
    elif kind=='3':
        o.update(method=ask('加密方式，例如 aes-256-gcm'),password=getpass.getpass('密码: '))
    else:
        o.update(uuid=str(uuid.UUID(ask('UUID'))),packet_encoding='xudp',tls={'enabled':kind=='4'})
        if kind=='4':
            o['flow']=input('Flow（回车 xtls-rprx-vision，输入 none 表示无）: ').strip() or 'xtls-rprx-vision'
            if o['flow']=='none': o.pop('flow')
            o['tls'].update(server_name=ask('SNI'),utls={'enabled':True,'fingerprint':'chrome'},reality={'enabled':True,'public_key':ask('Reality 公钥'),'short_id':input('Short ID（可空）: ').strip()})
    return o

def build(home,split,iface,google=None):
    home['bind_interface']=iface
    split['bind_interface']=iface
    if google is not None: google['bind_interface']=iface
    c = {'log':{'level':'info','timestamp':True},
    'dns':{'servers':[{'type':'udp','tag':'bootstrap','server':'223.5.5.5','detour':'direct'}, {'type':'tcp','tag':'dns-home','server':'8.8.8.8','detour':'home'}, {'type':'tcp','tag':'dns-split','server':'8.8.8.8','detour':'split'}, {'type':'tcp','tag':'dns-google','server':'8.8.8.8','detour':'google'}], 'rules':[{'rule_set':['google-domains'],'action':'route','server':'dns-google'}], 'final':'dns-split','reverse_mapping':True},
    'inbounds':[{'type':'tun','tag':'tun-in','interface_name':'tun0','address':['10.255.0.1/30','fdfe:dcba:9876::1/126'],'mtu':1500,'stack':'gvisor','auto_route':True,'auto_redirect':True,'strict_route':True}],
    'outbounds':[home,split,google,{'type':'direct','tag':'direct','bind_interface':iface,'domain_resolver':'bootstrap'}],
    'route':{'auto_detect_interface':True,'default_domain_resolver':'dns-split','rule_set':[{'type':'remote','tag':'ai-home','format':'binary','url':'https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/category-ai-!cn.srs','download_detour':'direct','update_interval':'24h'},{'type':'local','tag':'google-domains','format':'source','path':'/etc/sing-box/google.json'}],'rules':[{'port':53,'action':'hijack-dns'},{'ip_is_private':True,'action':'route','outbound':'direct'},{'ip_cidr': ['91.108.56.0/22', '91.108.4.0/22', '91.108.8.0/22', '91.108.16.0/22', '91.108.12.0/22', '149.154.160.0/20', '91.105.192.0/23', '91.108.20.0/22', '185.76.151.0/24', '2001:b28:f23d::/48', '2001:b28:f23f::/48', '2001:67c:4e8::/48', '2001:b28:f23c::/48', '2a0a:f280::/32'], 'action': 'route', 'outbound': 'home'},{'action':'sniff'},{'protocol':'dns','action':'hijack-dns'},{'rule_set':['google-domains'],'action':'route','outbound':'google'}], 'final':'split'}}
    if google is None:
        c['outbounds']=[o for o in c['outbounds'] if o is not None]
        c['dns']['servers']=[r for r in c['dns']['servers'] if r['tag']!='dns-google']
        c['dns']['rules']=[]
        c['route']['rules']=[r for r in c['route']['rules'] if r.get('outbound')!='google']
        c['route']['rule_set']=[r for r in c['route']['rule_set'] if r['tag']!='google-domains']
    c['experimental']={'cache_file':{'enabled':True,'path':'/var/lib/sing-box/cache.db'}}
    return c


def exclusions(c):
    for rs in c['route'].get('rule_set',[]):
        if rs.get('tag')=='ai-exclude': return rs['rules'][0]['domain_suffix']
    return []

def set_exclusions(c,values):
    c['route']['rule_set']=[rs for rs in c['route']['rule_set'] if rs['tag']!='ai-exclude']
    if values: c['route']['rule_set'].append({'type':'inline','tag':'ai-exclude','rules':[{'domain_suffix':sorted(set(values))}]})

def remote_names():
    # Display current upstream source; routing uses sing-box's independently refreshed SRS cache.
    url='https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/category-ai-!cn.json'
    with urllib.request.urlopen(url,timeout=10) as response: data=json.load(response)
    return sorted({d for r in data['rules'] for field in ('domain','domain_suffix') for d in r.get(field,[])})

def getlist(c):
    return sorted({d for r in c['route']['rules'] if r.get('outbound')=='home' for d in r.get('domain_suffix',[])})

def setlist(c,domains):
    selected=set(domains)
    c['route']['rules']=[r for r in c['route']['rules'] if (r.get('outbound')!='home' or 'ip_cidr' in r) and r.get('rule_set')!=['ai-exclude']]
    c['dns']['rules']=[r for r in c['dns']['rules'] if r.get('server')!='dns-home' and r.get('rule_set')!=['ai-exclude']]
    if exclusions(c):
        c['route']['rules'].append({'rule_set':['ai-exclude'],'action':'route','outbound':'split'})
        c['dns']['rules'].append({'rule_set':['ai-exclude'],'action':'route','server':'dns-split'})
    c['route']['rules'].append({'rule_set':['ai-home'],'action':'route','outbound':'home'})
    c['dns']['rules'].append({'rule_set':['ai-home'],'action':'route','server':'dns-home'})
    attachment='discord-attachments-uploads-prd.storage.googleapis.com'
    if attachment in selected:
        c['route']['rules'].insert(next((i for i,r in enumerate(c['route']['rules']) if r.get('outbound') in ('google','home') and 'ip_cidr' not in r),len(c['route']['rules'])),{'domain_suffix':[attachment],'action':'route','outbound':'home'})
        c['dns']['rules'].insert(0,{'domain_suffix':[attachment],'action':'route','server':'dns-home'})
    manual=sorted(selected-{attachment})
    if manual:
        c['route']['rules'].append({'domain_suffix':manual,'action':'route','outbound':'home'})
        c['dns']['rules'].append({'domain_suffix':manual,'action':'route','server':'dns-home'})


def setup():
    # Refuse legacy routing instead of flushing unrelated host rules.
    rules=subprocess.check_output(['ip','rule','show'],text=True)
    keep_unit=pathlib.Path('/etc/systemd/system/keep-alive.service')
    managed=keep_unit.exists() and 'Singbox-manager health check' in keep_unit.read_text()
    if re.search(r'lookup 100(?:\s|$)',rules) or (not managed and subprocess.run(['systemctl','is-active','--quiet','keep-alive']).returncode==0):
        raise RuntimeError('检测到旧 keep-alive 或 table 100 路由。请按 README 迁移后再安装，不会自动清空宿主机路由。')
    if CONFIG.exists():
        if input('将替换已有配置（保留备份）。输入 INSTALL 继续: ')!='INSTALL': raise RuntimeError('已取消安装')
    interfaces=[p.name for p in pathlib.Path('/sys/class/net').iterdir() if p.name!='lo']
    print('可用接口：'+', '.join(interfaces))
    iface=ask('机房出口网卡','eth0')
    if iface not in interfaces: raise ValueError('网卡不存在')
    home=node('home','家宽出口')
    split=node('split','分流出口')
    while True:
        choice=input('是否添加 Google 专用代理？[y/N]: ').strip().lower()
        if choice in ('','n','no','y','yes'): break
        print('请输入 y 或 n')
    google=node('google','Google 全系出口') if choice in ('y','yes') else None
    pathlib.Path('/var/lib/sing-box').mkdir(parents=True,exist_ok=True,mode=0o750)
    c=build(home,split,iface,google)
    defaults=json.loads((pathlib.Path(__file__).parent/'defaults.json').read_text())
    entries=sorted({domain(d) for group in defaults.values() for d in group} | set(getlist(c)))
    if CONFIG.exists():
        old_config=json.loads(CONFIG.read_text())
        entries=sorted(set(entries+getlist(old_config)))
        set_exclusions(c,exclusions(old_config))
    setlist(c,entries)
    old_google=(BASE/'google.json').read_bytes() if (BASE/'google.json').exists() else None
    if google is not None:
        atomic(BASE/'google.json',(pathlib.Path(__file__).parent/'google.json').read_bytes())
    unit=pathlib.Path('/etc/systemd/system/sing-box.service')
    previous=unit.read_bytes() if unit.exists() else None
    if previous: atomic(BASE/('service-backup-'+str(time.time_ns())),previous)
    content='''[Unit]
Description=Sing-box whitelist gateway
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
ExecStartPre=/usr/local/bin/sing-box check -c /etc/sing-box/config.json
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
'''
    previous_keep=keep_unit.read_bytes() if keep_unit.exists() else None
    if previous_keep: atomic(BASE/('keep-alive-backup-'+str(time.time_ns())),previous_keep)
    atomic(keep_unit,b'[Unit]\nDescription=Singbox-manager health check\nAfter=sing-box.service\nRequires=sing-box.service\n[Service]\nType=oneshot\nExecStart=/usr/bin/systemctl is-active --quiet sing-box.service\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n')
    atomic(unit,content.encode())
    run('systemctl','daemon-reload')
    try: apply(c)
    except BaseException:
        if old_google is not None: atomic(BASE/'google.json',old_google)
        else: (BASE/'google.json').unlink(missing_ok=True)
        if previous_keep: atomic(keep_unit,previous_keep)
        else: keep_unit.unlink(missing_ok=True)
        if previous: atomic(unit,previous)
        else: unit.unlink(missing_ok=True)
        run('systemctl','daemon-reload',check=False)
        if CONFIG.exists(): run('systemctl','restart','sing-box','keep-alive',check=False)
        raise
    run('systemctl','enable','sing-box','keep-alive')
    print('安装完成。已写入默认家宽白名单。'+('Google 优先走代理3。' if google is not None else '未启用 Google 专用出口，按普通白名单分流。')+'输入 singbox 管理。')

def menu():
    while True:
        print('\n1 添加域名白名单\n2 查看域名白名单\n3 搜索并删除白名单\n4 查看运行状态\n5 查看日志\n0 退出')
        choice=input('请选择: ').strip()
        try:
            if choice=='0': return
            if choice=='4': run('systemctl','status','sing-box','keep-alive','--no-pager','-l',check=False); continue
            if choice=='5':
                try: run('journalctl','-u','sing-box','-n','100','-f',check=False)
                except KeyboardInterrupt: print('\n返回菜单')
                continue
            if choice not in ('1','2','3'): continue
            with open(BASE/'manager.lock','a') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
                c=json.loads(CONFIG.read_text()); entries=getlist(c)
                if choice in ('2','3'):
                    try: upstream=remote_names()
                    except Exception as error:
                        print('无法读取上游域名目录，仅显示/搜索本地清单：',error); upstream=[]
                    excluded=exclusions(c)
                    visible=sorted(set(entries+[d for d in upstream if not any(d==e or d.endswith('.'+e) for e in excluded)]))
                    print('远程 AI 目录为上游当前版本，运行缓存最多有更新延迟；正则不列为普通域名。')
                if choice=='2':
                    print('\n'.join(visible) if visible else '清单为空')
                    print('本地排除：'+', '.join(exclusions(c)))
                    continue
                if choice=='1':
                    d=domain(ask('域名（包含该域及所有子域）'))
                    if d in entries and d not in exclusions(c): print('已存在（启用 Google 专用代理时，其规则优先于家宽白名单）'); continue
                    set_exclusions(c,[e for e in exclusions(c) if e!=d])
                    if any(d.endswith('.'+e) for e in exclusions(c)): raise ValueError('该域名被父域排除，请先重新添加父域解除排除')
                    if d not in entries: entries.append(d)
                    print('注意：若启用 Google 专用代理，Google 规则优先于此表。')
                else:
                    key=ask('搜索关键词').lower()
                    matches=[d for d in visible if key in d]
                    if not matches: print('没有匹配结果'); continue
                    for i,d in enumerate(matches,1): print(f'{i}. {d}')
                    selection=input('删除序号（回车取消）: ').strip()
                    if not selection: continue
                    n=int(selection)
                    if not 1<=n<=len(matches): raise ValueError('序号错误')
                    target=matches[n-1]
                    if input(f'确认删除 {target}？输入 y: ').lower()!='y': continue
                    if target in entries: entries.remove(target)
                    set_exclusions(c,exclusions(c)+[target])
                setlist(c,entries); apply(c); print('已保存并生效。重启服务可能中断现有连接。')
        except (ValueError,RuntimeError,OSError,subprocess.CalledProcessError) as e: print('操作失败：',e)

def main():
    if os.geteuid()!=0: sys.exit('请使用 sudo singbox')
    BASE.mkdir(parents=True,exist_ok=True)
    os.umask(0o077)
    if '--setup' in sys.argv:
        with open(BASE/'manager.lock','a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX); setup()
    else:
        if not CONFIG.exists(): sys.exit('请先运行安装脚本')
        menu()

if __name__=='__main__':
    try: main()
    except (KeyboardInterrupt,EOFError): print('\n已退出')
    except Exception as e: sys.exit(str(e))
SINGBOX_MANAGER_PY

# ===== 安装流程：内核检查、交互配置、安装 singbox 命令 =====
cat > "$SINGBOX_STAGE/install.sh" <<'SINGBOX_INSTALL_SH'
#!/usr/bin/env bash
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo '请用 root 执行'; exit 1; }
for dep in python3 ip systemctl curl tar; do command -v "$dep" >/dev/null || { echo "缺少依赖: $dep"; exit 1; }; done
DIR=$(cd -- "$(dirname -- "$0")" && pwd)
VERSION=1.12.15
case "$(uname -m)" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) echo '不支持的架构'; exit 1;; esac
if [ -x /usr/local/bin/sing-box ]; then
  /usr/local/bin/sing-box version | head -1 | grep -Fx "sing-box version $VERSION" >/dev/null || { echo '已有内核不是 1.12.15，请先自行备份并安装此版本'; exit 1; }
else
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  curl -fL --retry 3 --connect-timeout 20 "https://github.com/SagerNet/sing-box/releases/download/v$VERSION/sing-box-$VERSION-linux-$ARCH.tar.gz" -o "$TMP/core.tar.gz"
  tar -xzf "$TMP/core.tar.gz" -C "$TMP"
  install -m 0755 "$TMP/sing-box-$VERSION-linux-$ARCH/sing-box" /usr/local/bin/sing-box
fi
# Setup before installing menu, so failed setup does not replace an existing manager.
python3 "$DIR/singbox.py" --setup
install -m 0755 "$DIR/singbox.py" /usr/local/bin/singbox
SINGBOX_INSTALL_SH

# ===== 执行安装 =====
bash "$SINGBOX_STAGE/install.sh"
