` implements the OAuth1 signature algorithm `

` standard libraries `
std := load('../vendor/std')
str := load('../vendor/str')
json := load('../vendor/json')
quicksort := load('../vendor/quicksort')
percent := load('../vendor/percent')

` hmac-sha1 signing `
hmac := load('hmac')

log := std.log
f := std.format
hex := std.hex
xeh := std.xeh
map := std.map
cat := std.cat
slice := std.slice
join := std.join
upper := str.upper
ser := json.ser
sort := quicksort.sort
pctEncode := percent.encode

` Local credentials `
creds := load('../credentials')
ConsumerKey := creds.ConsumerKey
ConsumerSecret := creds.ConsumerSecret
OAuthToken := creds.OAuthToken
OAuthSecret := creds.OAuthSecret

` generate a unique nonce for use with OAuth `
nonce := () => (
	piece := () => (std.hex)(10000000000 * rand())
	piece() + piece() + piece() + piece()
)

` converting from hex (from HMAC) to base64 `
char64 := n => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.(n)
xxxTo64 := xxx => len(xxx) :: {
	` 4 padding bits, 2 padding =s `
	2 -> (
		first := floor(xeh(xxx.0 + xxx.1) / 4)
		second := (xeh(xxx.1) % 4) * 16
		char64(first) + char64(second) + '=='
	)
	` 2 padding bits, 1 padding = `
	4 -> (
		first := floor(xeh(xxx.0 + xxx.1) / 4)
		second := ((xeh(xxx.1) % 4) * 16) + xeh(xxx.2)
		third := xeh(xxx.3) * 4
		char64(first) + char64(second) + char64(third) + '='
	)
	` no padding bits, no padding =s `
	6 -> (
		first := floor(xeh(xxx.0 + xxx.1) / 4)
		second := ((xeh(xxx.1) % 4) * 16) + xeh(xxx.2)
		third := xeh(xxx.3) * 4 + floor(xeh(xxx.4) / 4)
		fourth := (xeh(xxx.4) % 4) * 16 + xeh(xxx.5)
		char64(first) + char64(second) + char64(third) + char64(fourth)
	)
}
base64Encode := inHex => (sub := (result, inHex) => len(inHex) :: {
	0 -> result
	_ -> sub(
		result + xxxTo64(slice(inHex, 0, 6))
		slice(inHex, 6, len(inHex))
	)
})('', inHex)

` sign is meant to wrap a request in the format normally passed to the req()
	builtin function. The return value of sign() is meant to be passed directly to
	req as the request object.

	req: request object, of the format req takes
	params: any query parameters normally passed to the request URL. sign will
	automatically append these parameters to the request URL`
sign := (req, params) => (
	` generate all variables `
	nonceStr := nonce()
	timestamp := string(floor(time()))

	queryStrings := map(keys(params), key => key + '=' + pctEncode(params.(key)))

	` OAuth HMAC signing requires that the query strings are sorted lexicographically `
	sortedParams := sort(join([
		'oauth_consumer_key=' + pctEncode(ConsumerKey)
		'oauth_nonce=' + pctEncode(nonceStr)
		'oauth_signature_method=HMAC-SHA1'
		'oauth_timestamp=' + timestamp
		'oauth_token=' + pctEncode(OAuthToken)
		'oauth_version=1.0'
	], queryStrings))

	` generate an OAuth signature for the status update request `
	paramString := cat(sortedParams, '&')
	base := cat([
		req.method
		pctEncode(req.url)
		pctEncode(paramString)
	], '&')
	signingKey := pctEncode(ConsumerSecret) + '&' + pctEncode(OAuthSecret)
	signature := base64Encode((hmac.sha1)(base, signingKey))

	` add the signature to the header `
	oauthParams := [
		'oauth_consumer_key="' + pctEncode(ConsumerKey) + '"'
		'oauth_nonce="' + pctEncode(nonceStr) + '"'
		'oauth_signature="' + pctEncode(signature) + '"'
		'oauth_signature_method="HMAC-SHA1"'
		'oauth_timestamp="' + timestamp + '"'
		'oauth_token="' + pctEncode(OAuthToken) + '"'
		'oauth_version="1.0"'
	]

	req.url := (params :: {
		{} -> req.url
		_ -> req.url + '?' + cat(queryStrings, '&')
	})
	req.headers := (req.headers :: {
		() -> {
			Authorization: 'OAuth ' + cat(oauthParams, ', ')
		}
		_ -> req.headers.Authorization := 'OAuth ' + cat(oauthParams, ', ')
	})

	req
)

