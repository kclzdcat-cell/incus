#!/usr/bin/env bash
# LazyCat Sing-box：完整明文单文件安装器
# 上传本文件到 GitHub，下载后执行：sudo bash singbox-install.sh
# 前置依赖：Linux/systemd、Python 3.9+、curl、tar、iproute2。
# 本文件直接包含管理程序和默认规则，不含 Base64 或压缩编码载荷。
# 临时目录用于安装期间展开源码；退出后自动删除。
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo '请使用 sudo bash singbox-install.sh'; exit 1; }
command -v python3 >/dev/null || { echo '请先安装 Python 3.9 或更高版本'; exit 1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,9) else "需要 Python 3.9 或更高版本")'
umask 077
SINGBOX_STAGE=$(mktemp -d)
trap 'rm -rf -- "$SINGBOX_STAGE"' EXIT

# ===== 默认家宽域名：可直接编辑下方 JSON =====
cat > "$SINGBOX_STAGE/defaults.json" <<'SINGBOX_DEFAULT_DOMAINS'
{
  "IP检测": [
    "abuseipdb.com",
    "api.myip.com",
    "browserleaks.com",
    "check.place",
    "checkip.amazonaws.com",
    "cip.cc",
    "db-ip.com",
    "dnsleaktest.com",
    "geoip.com",
    "icanhazip.com",
    "ident.me",
    "ifconfig.co",
    "ifconfig.me",
    "ip-api.com",
    "ip.sb",
    "ip.skk.moe",
    "ip138.com",
    "ip2location.com",
    "ip2location.io",
    "ip2proxy.com",
    "ipaddress.com",
    "ipapi.co",
    "ipapi.com",
    "ipapi.is",
    "ipdata.co",
    "ipdb.io",
    "ipgeolocation.io",
    "ipify.org",
    "ipinfo.io",
    "ipip.net",
    "iplark.com",
    "ipleak.net",
    "iplocation.net",
    "ipqualityscore.com",
    "ipregistry.co",
    "ipwho.is",
    "ipwhois.io",
    "maxmind.com",
    "myip.com",
    "ping0.cc",
    "scamalytics.com",
    "whatismyip.com",
    "whatismyipaddress.com"
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

def align_disabled_ipv6(c):
    """Remove IPv6 TUN addresses only where the kernel explicitly disables IPv6."""
    removed=[]
    root=pathlib.Path('/proc/sys/net/ipv6/conf')
    def disabled(name):
        try: return (root/name/'disable_ipv6').read_text().strip()=='1'
        except OSError: return False
    globally_disabled=disabled('all') or disabled('default')
    for inbound in c.get('inbounds',[]):
        if inbound.get('type')!='tun': continue
        if not (globally_disabled or disabled(inbound.get('interface_name','tun0'))): continue
        addresses=inbound.get('address',[])
        if isinstance(addresses,str): addresses=[addresses]
        ipv4=[a for a in addresses if ipaddress.ip_interface(a).version==4]
        ipv6=[a for a in addresses if ipaddress.ip_interface(a).version==6]
        if ipv6:
            if not ipv4: raise RuntimeError('IPv6 已禁用且 TUN 没有 IPv4 地址，请先配置 IPv4 TUN 地址')
            inbound['address']=ipv4;removed.extend(ipv6)
    if globally_disabled:
        c.setdefault('dns',{})['strategy']='ipv4_only'
        for rule in c['dns'].get('rules',[]):
            if rule.get('action','route')=='route': rule['strategy']='ipv4_only'
    return removed

def apply(c):
    removed=align_disabled_ipv6(c)
    if removed: print('系统已禁用 IPv6，已移除 TUN IPv6 地址：'+', '.join(removed))
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
    while True:
        v=input(label+(f' [{default}]' if default else '')+': ').strip() or default
        if v: return v
        print('此项不能为空，请重新输入。')

def select(title,options,default=None):
    print('\n'+'─'*44)
    print(title)
    print('─'*44)
    for i,label in enumerate(options,1):
        print(f'  [{i}] {label}'+('（默认）' if i==default else ''))
    print('─'*44)
    while True:
        value=input('请输入选项序号'+(f'，回车选择 {default}' if default else '')+': ').strip()
        if not value and default is not None: return default
        if value.isdigit() and 1<=int(value)<=len(options): return int(value)
        print(f'请输入 1 至 {len(options)} 的序号。')

def validated(label,convert):
    while True:
        try: return convert(ask(label))
        except (ValueError,UnicodeError) as error: print('输入无效：'+str(error)+'，请重新输入。')

def server_host(value):
    value=value.strip('[]')
    try: return str(ipaddress.ip_address(value))
    except ValueError: return domain(value)

def server_port(value):
    value=int(value)
    if not 1<=value<=65535: raise ValueError('端口必须在 1–65535 之间')
    return value

def node(tag,label):
    kind=str(select('设置'+label+' · 选择协议',['SOCKS5','VLESS（TCP，无 TLS）','Shadowsocks','VLESS + Reality']))
    print('\n请输入'+label+'的连接信息：')
    host=validated('服务器 IP 或域名',server_host)
    port=validated('端口',server_port)
    o={'type':{'1':'socks','2':'vless','3':'shadowsocks','4':'vless'}[kind], 'tag':tag,'server':host,'server_port':port,'domain_resolver':'bootstrap'}
    if kind=='1':
        o.update(version='5',username=input('用户名（可空）: ').strip(),password=getpass.getpass('密码（可空）: '))
    elif kind=='3':
        methods=['aes-256-gcm','aes-128-gcm','chacha20-ietf-poly1305','2022-blake3-aes-128-gcm','2022-blake3-aes-256-gcm','2022-blake3-chacha20-poly1305']
        method=select('选择 Shadowsocks 加密方式',methods+['手动输入其他加密方式'])
        o['method']=methods[method-1] if method<=len(methods) else ask('加密方式')
        while True:
            o['password']=getpass.getpass('密码: ')
            if o['password']: break
            print('密码不能为空，请重新输入。')
    else:
        o.update(uuid=validated('UUID',lambda v:str(uuid.UUID(v))),packet_encoding='xudp',tls={'enabled':kind=='4'})
        if kind=='4':
            flow=select('选择 Reality Flow',['xtls-rprx-vision','无 Flow'],default=1)
            if flow==1: o['flow']='xtls-rprx-vision'
            o['tls'].update(server_name=ask('SNI'),utls={'enabled':True,'fingerprint':'chrome'},reality={'enabled':True,'public_key':ask('Reality 公钥'),'short_id':input('Short ID（可空）: ').strip()})
    print('已录入'+label+'。')
    return o


def build(home,split,iface,google=None):
    home['bind_interface']=iface
    if split is None:
        split={'type':'direct','tag':'split','domain_resolver':'bootstrap'}
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
    align_disabled_ipv6(c)
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
    # Home-path IPv6 failed in deployment diagnostics; filter only home DNS answers.
    for rule in c['dns']['rules']:
        if rule.get('server')=='dns-home': rule['strategy']='ipv4_only'



def legacy_commands(keep_unit):
    """Recognize the user's original script; never execute it or flush host tables."""
    old=pathlib.Path('/root/keep_alive.sh')
    text=old.read_text() if old.exists() else ''
    signature=['MARK_OUTBOUND_HEX="0x29a"','MARK_INBOUND_HEX="0x114"','TABLE_TUN="100"','ip route flush table','CONNMARK --restore-mark']
    if not all(x in text for x in signature) or not keep_unit.exists() or '/root/keep_alive.sh' not in keep_unit.read_text():
        raise RuntimeError('旧规则不符合已知脚本，无法确定归属，未清理。请提供 ip rule show 和 keep-alive.service 内容。')
    match=re.search(r'^IFACE_WAN="([a-zA-Z0-9_.:-]+)"$',text,re.M)
    if not match: raise RuntimeError('无法识别旧出口网卡，未清理')
    wan=match.group(1)
    commands=[]
    def rule(args): commands.append((['ip','rule','del']+args,['ip','rule','add']+args))
    # Remove global interception first. Remaining specific rules cannot trap SSH.
    rule(['priority','100','from','all','lookup','100'])
    match=re.search(r'^SSH_CLIENT_IP="([^"\n]*)"$',text,re.M)
    if match and match.group(1):
        address=str(ipaddress.IPv4Address(match.group(1)))
        for direction in ('from','to'): rule(['priority','10',direction,address,'lookup','main'])
    for port in ('sport','dport'): rule(['priority','15','ipproto','tcp',port,'22','lookup','main'])
    for priority,mark in [('50','0x114'),('60','0x29a')]: rule(['priority',priority,'fwmark',mark,'lookup','main'])
    public=['140.82.112.0/20','143.55.64.0/20','185.199.108.0/22','192.30.252.0/22','20.201.28.0/24','4.208.26.0/24','44.205.64.0/20','52.1.184.0/21','54.198.86.0/24']
    for cidr in ['10.0.0.0/8','172.16.0.0/12','192.168.0.0/16']+public:
        rule(['priority','70','to',cidr,'lookup','main'])
    def firewall(chain,args):
        commands.append((['iptables','-w','5','-t','mangle','-D',chain]+args,['iptables','-w','5','-t','mangle','-A',chain]+args))
    firewall('PREROUTING',['-i',wan,'-p','tcp','--dport','22','-j','ACCEPT'])
    for chain in ('PREROUTING','OUTPUT'):
        for cidr in public: firewall(chain,['-d',cidr,'-j','ACCEPT'])
    firewall('PREROUTING',['-i',wan,'-m','conntrack','--ctstate','NEW','-j','CONNMARK','--set-mark','0x114'])
    firewall('PREROUTING',['-m','connmark','--mark','0x114','-j','CONNMARK','--restore-mark'])
    firewall('OUTPUT',['-p','tcp','--sport','22','-j','ACCEPT'])
    firewall('OUTPUT',['-m','connmark','--mark','0x114','-j','CONNMARK','--restore-mark'])
    commands.append((['ip','route','del','table','100','default','dev','tun0'],['ip','route','add','table','100','default','dev','tun0']))
    return commands

def clean_legacy(commands,undo):
    backup=BASE/('legacy-network-'+str(time.time_ns())+'.txt')
    snapshots=[]
    for args in (['ip','rule','show'],['ip','route','show','table','100'],['iptables-save']):
        result=subprocess.run(args,capture_output=True,text=True)
        snapshots.append(' '.join(args)+'\n'+result.stdout+result.stderr)
    atomic(backup,'\n'.join(snapshots).encode())
    run('systemctl','stop','keep-alive')
    for delete,restore in commands:
        # Delete exact known entries only, including duplicates from the old loop.
        for _ in range(128):
            result=subprocess.run(delete,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            if delete[0]=='iptables' and result.returncode not in (0,1): raise RuntimeError('清理旧 iptables 规则失败')
            if result.returncode: break
            undo.append(restore)
        else: raise RuntimeError('旧规则重复数量异常，停止迁移并回滚')
    rules=subprocess.check_output(['ip','rule','show'],text=True)
    if re.search(r'lookup 100(?:\s|$)',rules): raise RuntimeError('仍有不属于原脚本的 table 100 引用，停止迁移并回滚')
    print('已清理匹配的旧规则，网络快照：'+str(backup))

def interface_choice(value,interfaces,default):
    value=value.strip()
    if not value: return default
    if value in interfaces: return value
    if value.isdigit() and 1<=int(value)<=len(interfaces): return interfaces[int(value)-1]
    raise ValueError('请选择列表中的序号或完整网卡名')

def choose_interface():
    interfaces=sorted(p.name for p in pathlib.Path('/sys/class/net').iterdir() if p.name!='lo')
    if not interfaces: raise RuntimeError('未发现网络接口')
    # Read the main table; the old policy-routing default may point to tun0.
    default=None
    result=subprocess.run(['ip','-j','-4','route','show','table','main','default'],capture_output=True,text=True)
    try:
        routes=json.loads(result.stdout)
        for route in sorted(routes,key=lambda r:r.get('metric',0)):
            if route.get('dev') in interfaces:
                default=route['dev']; break
    except (ValueError,TypeError): pass
    default=default or ('eth0' if 'eth0' in interfaces else interfaces[0])
    interfaces=[default]+[name for name in interfaces if name!=default]
    print('请选择机房出口网卡（不要选择容器桥接或 TUN 接口）：')
    for i,name in enumerate(interfaces,1):
        print(f'  [{i}] {name}'+('（默认）' if name==default else ''))
    while True:
        value=input(f'输入序号或网卡名称，回车使用 {default}: ')
        try:
            selected=interface_choice(value,interfaces,default)
            print('已选择出口网卡：'+selected)
            return selected
        except ValueError as error: print(str(error)+'，请重新输入。')

def setup():
    rules=subprocess.check_output(['ip','rule','show'],text=True)
    keep_unit=pathlib.Path('/etc/systemd/system/keep-alive.service')
    managed=keep_unit.exists() and 'Singbox-manager health check' in keep_unit.read_text()
    legacy=bool(re.search(r'lookup 100(?:\s|$)',rules)) or (not managed and subprocess.run(['systemctl','is-active','--quiet','keep-alive']).returncode==0)
    legacy_plan=legacy_commands(keep_unit) if legacy else []
    if legacy: print('已识别旧版部署：输入节点并检查配置后，将自动清理旧规则，无需重启宿主机。')
    if CONFIG.exists():
        if select('检测到已有配置',['备份并重新配置','取消安装'],default=2)!=1: raise RuntimeError('已取消安装')
    iface=choose_interface()
    home=node('home','代理1 · 家宽出口')
    split_choice=select('代理2 · 默认分流出口',['添加分流代理','不添加，使用机房直连'],default=2)
    split=node('split','代理2 · 分流出口') if split_choice==1 else None
    choice=select('是否添加 Google 专用代理？',['添加 Google 专用代理','不添加，按现有白名单分流'],default=2)
    google=node('google','代理3 · Google 出口') if choice==1 else None
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
    candidate=BASE/'migration-check.json'
    atomic(candidate,encode(c))
    try: run(BIN,'check','-c',str(candidate))
    finally: candidate.unlink(missing_ok=True)
    undo=[]
    try:
        if legacy: clean_legacy(legacy_plan,undo)
        atomic(keep_unit,b'[Unit]\nDescription=Singbox-manager health check\nAfter=sing-box.service\nRequires=sing-box.service\n[Service]\nType=oneshot\nExecStart=/usr/bin/systemctl is-active --quiet sing-box.service\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n')
        atomic(unit,content.encode())
        run('systemctl','daemon-reload')
        apply(c)
    except BaseException:
        if old_google is not None: atomic(BASE/'google.json',old_google)
        else: (BASE/'google.json').unlink(missing_ok=True)
        if previous_keep: atomic(keep_unit,previous_keep)
        else: keep_unit.unlink(missing_ok=True)
        if previous: atomic(unit,previous)
        else: unit.unlink(missing_ok=True)
        run('systemctl','daemon-reload',check=False)
        restore_commands=[x for x in undo if x[0]=='iptables']+[x for x in reversed(undo) if x[0]!='iptables']
        for command in restore_commands:
            subprocess.run(command,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        if CONFIG.exists(): run('systemctl','restart','sing-box','keep-alive',check=False)
        raise
    run('systemctl','enable','sing-box','keep-alive')
    print('安装完成。已写入默认家宽白名单。'+('默认出口：分流代理。' if split is not None else '默认出口：机房直连。')+('Google 优先走代理3。' if google is not None else '未启用 Google 专用出口，按普通白名单分流。')+'输入 singbox 管理。')

def check_ip():
    print('通过 HTTPS 下载 IPQuality 检测脚本；不修改分流配置。')
    with tempfile.TemporaryDirectory(prefix='singbox-ipcheck-') as directory:
        path=pathlib.Path(directory)/'ipquality.sh'
        run('curl','-4','-fSL','--proto','=https','--proto-redir','=https',
            '--connect-timeout','10','--max-time','60','--retry','2',
            'https://IP.Check.Place','-o',str(path))
        data=path.read_bytes()
        if not data.strip(): raise RuntimeError('下载内容为空，未执行检测脚本')
        first=data.splitlines()[0].strip()
        if first not in (b'#!/bin/bash',b'#!/usr/bin/env bash'):
            raise RuntimeError('下载内容不是预期的 Bash 脚本，未执行；可能返回了验证页或错误页')
        run('bash','-n',str(path))
        run('bash',str(path))

def validate_backup_shape(c):
    if not isinstance(c,dict): raise ValueError('备份必须是 sing-box 配置 JSON 对象')
    for key in ('inbounds','outbounds'):
        if not isinstance(c.get(key),list): raise ValueError('备份缺少 '+key+' 数组')
    if not isinstance(c.get('route'),dict) or not isinstance(c.get('dns'),dict):
        raise ValueError('备份缺少 route 或 dns 配置')
    if not all(isinstance(o,dict) for o in c['outbounds']): raise ValueError('outbounds 内容无效')
    if not {'home','split'}.issubset({o.get('tag') for o in c['outbounds']}):
        raise ValueError('此文件缺少本管理器的 home / split 出口，不能直接恢复')

def export_backup():
    with open(BASE/'manager.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        c=json.loads(CONFIG.read_text())
        validate_backup_shape(c)
        # Embed local rule sets so Google rules remain available on another host.
        for rule in c['route'].get('rule_set',[]):
            if rule.get('type')!='local': continue
            source=pathlib.Path(rule['path'])
            if not source.is_absolute():
                raise ValueError('本地规则路径不是绝对路径，无法可靠导出：'+str(source))
            fmt=rule.get('format') or ('binary' if source.suffix=='.srs' else 'source')
            if fmt=='source': data=json.loads(source.read_text())
            elif fmt=='binary':
                with tempfile.TemporaryDirectory(prefix='singbox-export-') as temp:
                    output=pathlib.Path(temp)/'rules.json'
                    run(BIN,'rule-set','decompile','--output',str(output),str(source))
                    data=json.loads(output.read_text())
            else: raise ValueError('不支持的本地规则格式：'+fmt)
            if not isinstance(data.get('rules'),list): raise ValueError('本地规则内容无效')
            tag=rule['tag'];rule.clear();rule.update(type='inline',tag=tag,rules=data['rules'])
        fd,name=tempfile.mkstemp(prefix='singbox-backup-'+time.strftime('%Y%m%d-%H%M%S')+'-',suffix='.json',dir=pathlib.Path.cwd())
        try:
            with os.fdopen(fd,'wb') as f:
                f.write(encode(c));f.flush();os.fsync(f.fileno())
        except BaseException:
            pathlib.Path(name).unlink(missing_ok=True);raise
    print('已导出备份：'+str(pathlib.Path(name).resolve()))
    print('文件权限 600，包含节点凭据、白名单和排除项；本地规则已内嵌。远程规则保留下载地址。')
    return pathlib.Path(name)

def restore_backup():
    directory=pathlib.Path.cwd()
    files=sorted((p for p in directory.glob('*.json') if p.is_file() and not p.is_symlink() and p.resolve()!=CONFIG.resolve()),key=lambda p:p.name)
    if not files:
        print('当前目录没有可恢复的 JSON 文件：'+str(directory));return
    choice=select('从当前目录恢复：'+str(directory),[p.name for p in files]+['取消，返回菜单'],default=len(files)+1)
    if choice==len(files)+1: return
    path=files[choice-1]
    c=json.loads(path.read_text(encoding='utf-8-sig'))
    validate_backup_shape(c)
    if select('恢复 '+path.name+'？当前配置将备份，服务会重启。',['恢复备份','取消'],default=2)!=1: return
    with open(BASE/'manager.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        # Existing remote cache path is owned by the installed service.
        if c.get('experimental',{}).get('cache_file',{}).get('enabled'):
            cache=c['experimental']['cache_file']
            cache['path']='/var/lib/sing-box/cache.db'
            pathlib.Path('/var/lib/sing-box').mkdir(parents=True,exist_ok=True,mode=0o750)
        apply(c)
    print('备份恢复成功。原配置备份位于 '+str(BASE)+'，文件名以 backup- 开头。')
    print('网卡与上游连通性仍需在本机验证；系统禁用 IPv6 时会自动调整 TUN 地址。')

def menu():
    while True:
        print('\n1 添加域名白名单\n2 查看域名白名单\n3 搜索并删除白名单\n4 查看运行状态\n5 查看日志\n6 IP 质量检测（HTTPS 下载）\n7 导出 JSON 备份到当前目录\n8 从当前目录恢复 JSON 备份\n0 退出')
        choice=input('请选择: ').strip()
        try:
            if choice=='0': return
            if choice=='7': export_backup(); continue
            if choice=='8': restore_backup(); continue
            if choice=='6':
                try: check_ip()
                except KeyboardInterrupt: print('\n检测已中断，返回菜单')
                continue
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
                    if select(f'确认删除 {target}？',['删除并保存','取消'],default=2)!=1: continue
                    if target in entries: entries.remove(target)
                    set_exclusions(c,exclusions(c)+[target])
                setlist(c,entries); apply(c); print('已保存并生效。重启服务可能中断现有连接。')
        except (ValueError,RuntimeError,OSError,subprocess.CalledProcessError) as e: print('操作失败：',e)

def main():
    if os.geteuid()!=0: sys.exit('请使用 sudo singbox')
    BASE.mkdir(parents=True,exist_ok=True)
    os.umask(0o077)
    if '--repair-tun' in sys.argv:
        with open(BASE/'manager.lock','a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            c=json.loads(CONFIG.read_text())
            removed=align_disabled_ipv6(c)
            if not removed: raise RuntimeError('未发现 IPv6 禁用与 TUN 地址冲突，未修改；需检查 systemctl cat sing-box 和 TUN 权限')
            print('检测到冲突的 TUN IPv6 地址：'+', '.join(removed))
            apply(c)
            print('TUN 配置修复完成，服务已重启。')
    elif '--check-ip' in sys.argv:
        check_ip()
    elif '--setup' in sys.argv:
        with open(BASE/'manager.lock','a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX); setup()
    else:
        if not CONFIG.exists(): print('配置文件不存在：可选择 8 恢复备份，或重新运行安装器。')
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
if [ "${1:-}" = "--repair-tun" ]; then
  python3 "$DIR/singbox.py" --repair-tun
  if [ -f /usr/local/bin/singbox ]; then
    cp -p /usr/local/bin/singbox "/etc/sing-box/manager-backup-$(date +%s)-$$.py"
  fi
  install -m 0755 "$DIR/singbox.py" /usr/local/bin/singbox
  echo '管理器已同步升级；后续菜单写配置会检测系统 IPv6 禁用状态。'
  exit 0
fi
if [ "${1:-}" = "--update-manager" ]; then
  [ -f /etc/sing-box/config.json ] && [ -f /usr/local/bin/singbox ] || { echo '未找到现有管理器，请先完成安装'; exit 1; }
  python3 - "$DIR/singbox.py" <<'CHECK_MANAGER'
import sys,pathlib
compile(pathlib.Path(sys.argv[1]).read_text(),sys.argv[1],'exec')
CHECK_MANAGER
  cp -p /usr/local/bin/singbox "/etc/sing-box/manager-backup-$(date +%s)-$$.py"
  install -m 0755 "$DIR/singbox.py" /usr/local/bin/singbox
  echo '管理器已更新，节点、白名单及路由配置未改动，也未重启服务。输入 singbox，选择 6 检测。'
  exit 0
fi
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
bash "$SINGBOX_STAGE/install.sh" "$@"
