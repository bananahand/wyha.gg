vcl 4.0;

backend default {
  .host = "127.0.0.1";
  .port = "80";
  .connect_timeout = 3600s;
  .first_byte_timeout = 3600s;
  .between_bytes_timeout = 3600s;
}

backend node {
  .host = "127.0.0.1";
  .port = "6969";
  .connect_timeout = 3600s;
  .first_byte_timeout = 3600s;
  .between_bytes_timeout = 3600s;
}
 
sub vcl_recv {
  unset req.http.X-Forwarded-For;
  set req.http.X-Forwarded-For = client.ip;
 
  if (req.url ~ ".*/cron.php$") {
    return (pass);
  }
 
    if (req.url ~ "(^/office.json|^/throwback.json)") {
        set req.backend_hint = node;
    } else {
        set req.backend_hint = default;
    }

# Add any additional cron-type files here.
# Enable this (modifying "active-lb" as necessary) if you're behind a LB with active checking.
#  if (req.url ~ ".*/active-lb.php$") {
#   return (pass);
#  }
 
  set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z0-9A-Z_-]+|has_js)=[^;]*", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(s_cc|s_sq|Drupal_toolbar_collapsed)=[^;]*", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(base_domain_|fbsetting_)[^;]*", "");
  set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
  if (req.http.Cookie ~ "^\s*$") {
    unset req.http.Cookie;
    unset req.http.Cookie;
  }
 
  # cache these file types - remember to also update vcl_fetch if you change this list!
  if ( req.url ~ "(?i)\.(jpg|png|css|js|ico|gz|tgz|bz2|tbz|gif|mp3|ogg|swf)$" ) {
    unset req.http.cookie;
    unset req.http.cookie;
  }
 
  # Deliver expired objects during non-HFP bereqs for this period.  Note that this
  # won't do very much unless you kill the ttl <= 0 clause in vcl_fetch().
  #set req.grace = 30s;
 
  # Force lookup if the request is a no-cache request from the client
  if (req.http.Cache-Control ~ "no-cache") {
    return(pass);
  }
 
  # Properly handle different encoding types
  if (req.http.Accept-Encoding) {
    if (req.url ~ "(?i)\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
    # No point in compressing these
      unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      # unknown algorithm
      unset req.http.Accept-Encoding;
    }
  }
 
  if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "DELETE") {
      # Non-RFC2616 or CONNECT (which is weird).
      return (pipe);
  }
 
  if (req.method != "GET" && req.method != "HEAD") {
    # We only deal with GET and HEAD by default
    return (pass);
  }
 
  if (req.http.Authorization || req.http.Cookie) {
    # Not cacheable by default
    return (pass);
  }
 
  # Explicitly return(lookup), because otherwise the default vcl_recv()
  # will be executed.
  return (hash);
}
 
sub vcl_pipe {
  # Deep Magic; without this, we lose X-F-F and rewrites.
  set bereq.http.Connection = "close";
}
 
sub vcl_hash {
  # Needed for Grace and ESI situations; never serve someone someone else's
  # personalized page.
  if ( req.http.Cookie ) {
    hash_data( req.http.Cookie );
  }
}
 
sub vcl_backend_response {
  # Since we strip cookies, if for some reason these give us something that
  # runs PHP (e.g. a 404), if we don't strip out the set-cookie, we'll be
  # treated as an anonymous user and given a fresh cookie.
  
  unset beresp.http.Server;
  unset beresp.http.X-Powered-By;

  if ( bereq.url ~ "(?i)\.(jpg|png|css|js|ico|gz|tgz|bz2|tbz|gif|mp3|ogg|swf)$" ) {
    unset beresp.http.Set-Cookie;
  }
 
  # This is the maximum time beyond its expiration for which we'll keep an
  # object in cache.
  set beresp.grace = 10d;

  if (bereq.url ~ "(^/office.json|^/throwback.json)") {
    set beresp.ttl = 5s;
  }
 
  # This line doesn't play very nicely with Grace.  If you have a backend health
  # check configured, update the TTL portion appropriately.
    if (beresp.http.X-No-Cache) {
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return (deliver);
    }
  return (deliver);
}

sub vcl_deliver {
  unset resp.http.Via;
  unset resp.http.X-Varnish;
  set resp.http.X-Powered-By = "RFC 2549";
  set resp.http.Upgrade = "HTTP/2.0";
}
