---
title: "Caddy源码阅读"
date: 2022-06-14T14:33:18+08:00
draft: false
categories: [ "undefined"]
tags: 
- golang
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

之前我们用了caddy的forwardproxy插件，来看看他是怎么做的

## go内置的http服务器实现

```go
http.ListenAndServe(":8080", nil)
```

如上即可启动go内置的http服务器，第二个参数是nil，于是go会使用内置的handler，代码如下

```go
func (sh serverHandler) ServeHTTP(rw ResponseWriter, req *Request) {
	handler := sh.srv.Handler
	if handler == nil { // 如果为nil，则使用内置的ServeMux
		handler = DefaultServeMux
	}
	if req.RequestURI == "*" && req.Method == "OPTIONS" {
		handler = globalOptionsHandler{}
	}
	handler.ServeHTTP(rw, req)
}
```

DefaultServeMux 负责匹配url和handleFunc，确定改请求由谁处理。

## caddy自定义的handle和其责任链模式

caddy自定义了handle，在

```
github.com/caddyserver/caddy/caddyhttp/HttpServer.Server
```

```go
// ServeHTTP is the entry point of all HTTP requests.
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	defer func() {
		// We absolutely need to be sure we stay alive up here,
		// even though, in theory, the errors middleware does this.
		if rec := recover(); rec != nil {
			log.Printf("[PANIC] %v", rec)
			DefaultErrorFunc(w, r, http.StatusInternalServerError)
		}
	}()

	// record the User-Agent string (with a cap on its length to mitigate attacks)
	ua := r.Header.Get("User-Agent")
	if len(ua) > 512 {
		ua = ua[:512]
	}
	uaHash := telemetry.FastHash([]byte(ua)) // this is a normalized field
	go telemetry.SetNested("http_user_agent", uaHash, ua)
	go telemetry.AppendUnique("http_user_agent_count", uaHash)
	go telemetry.Increment("http_request_count")

	// copy the original, unchanged URL into the context
	// so it can be referenced by middlewares
	urlCopy := *r.URL
	if r.URL.User != nil {
		userInfo := new(url.Userinfo)
		*userInfo = *r.URL.User
		urlCopy.User = userInfo
	}
	c := context.WithValue(r.Context(), OriginalURLCtxKey, urlCopy)
	r = r.WithContext(c)

	// Setup a replacer for the request that keeps track of placeholder
	// values across plugins.
	replacer := NewReplacer(r, nil, "")
	c = context.WithValue(r.Context(), ReplacerCtxKey, replacer)
	r = r.WithContext(c)

	w.Header().Set("Server", caddy.AppName)

	status, _ := s.serveHTTP(w, r)

	// Fallback error response in case error handling wasn't chained in
	if status >= 400 {
		DefaultErrorFunc(w, r, status)
	}
}

func (s *Server) serveHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	// strip out the port because it's not used in virtual
	// hosting; the port is irrelevant because each listener
	// is on a different port.
	hostname, _, err := net.SplitHostPort(r.Host)
	if err != nil {
		hostname = r.Host
	}

	// look up the virtualhost; if no match, serve error
	vhost, pathPrefix := s.vhosts.Match(hostname + r.URL.Path)
	c := context.WithValue(r.Context(), caddy.CtxKey("path_prefix"), pathPrefix)
	r = r.WithContext(c)

	if vhost == nil {
		// check for ACME challenge even if vhost is nil;
		// could be a new host coming online soon - choose any
		// vhost's cert manager configuration, I guess
		if len(s.sites) > 0 && s.sites[0].TLS.Manager.HandleHTTPChallenge(w, r) {
			return 0, nil
		}

		// otherwise, log the error and write a message to the client
		remoteHost, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			remoteHost = r.RemoteAddr
		}
		WriteSiteNotFound(w, r) // don't add headers outside of this function (http.forwardproxy)
		log.Printf("[INFO] %s - No such site at %s (Remote: %s, Referer: %s)",
			hostname, s.Server.Addr, remoteHost, r.Header.Get("Referer"))
		return 0, nil
	}

	// we still check for ACME challenge if the vhost exists,
	// because the HTTP challenge might be disabled by its config
	if vhost.TLS.Manager.HandleHTTPChallenge(w, r) {
		return 0, nil
	}

	// trim the path portion of the site address from the beginning of
	// the URL path, so a request to example.com/foo/blog on the site
	// defined as example.com/foo appears as /blog instead of /foo/blog.
	if pathPrefix != "/" {
		r.URL = trimPathPrefix(r.URL, pathPrefix)
	}

	// enforce strict host matching, which ensures that the SNI
	// value (if any), matches the Host header; essential for
	// sites that rely on TLS ClientAuth sharing a port with
	// sites that do not - if mismatched, close the connection
	if vhost.StrictHostMatching && r.TLS != nil &&
		strings.ToLower(r.TLS.ServerName) != strings.ToLower(hostname) {
		r.Close = true
		log.Printf("[ERROR] %s - strict host matching: SNI (%s) and HTTP Host (%s) values differ",
			vhost.Addr, r.TLS.ServerName, hostname)
		return http.StatusForbidden, nil
	}

	return vhost.middlewareChain.ServeHTTP(w, r)
}
```
