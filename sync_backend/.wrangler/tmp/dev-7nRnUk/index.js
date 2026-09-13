var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.ts
var GOOGLE_CLIENT_ID = "227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com";
async function verifyGoogleToken(idToken) {
  try {
    const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
    if (!response.ok) {
      return null;
    }
    const payload = await response.json();
    const validIssuers = ["accounts.google.com", "https://accounts.google.com"];
    if (!validIssuers.includes(payload.iss))
      return null;
    if (payload.aud !== GOOGLE_CLIENT_ID)
      return null;
    const expTime = parseInt(payload.exp, 10);
    const currentTime = Math.floor(Date.now() / 1e3);
    if (expTime < currentTime)
      return null;
    return payload.sub;
  } catch (e) {
    return null;
  }
}
__name(verifyGoogleToken, "verifyGoogleToken");
var src_default = {
  async fetch(request, env, ctx) {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response("Unauthorized", { status: 401 });
    }
    const token = authHeader.substring(7);
    const sub = await verifyGoogleToken(token);
    if (!sub) {
      return new Response("Unauthorized", { status: 401 });
    }
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/sync") {
      const { results: stateResults } = await env.DB.prepare(
        "SELECT key, value, updated_at FROM user_state WHERE sub = ?"
      ).bind(sub).all();
      const { results: countersResults } = await env.DB.prepare(
        "SELECT key, SUM(increment_value) as total FROM user_counters WHERE sub = ? GROUP BY key"
      ).bind(sub).all();
      return Response.json({
        state: stateResults,
        counters: countersResults
      });
    }
    if (request.method === "POST" && url.pathname === "/sync") {
      try {
        const body = await request.json();
        const statements = [];
        if (Array.isArray(body.updates)) {
          for (const update of body.updates) {
            if (update.key && update.value && update.updated_at !== void 0) {
              statements.push(
                env.DB.prepare(
                  `INSERT INTO user_state (sub, key, value, updated_at) 
									 VALUES (?, ?, ?, ?) 
									 ON CONFLICT(sub, key) DO UPDATE SET 
									 value = excluded.value, 
									 updated_at = excluded.updated_at 
									 WHERE excluded.updated_at > user_state.updated_at`
                ).bind(sub, update.key, update.value, update.updated_at)
              );
            }
          }
        }
        if (Array.isArray(body.counters)) {
          for (const counter of body.counters) {
            if (counter.key && counter.event_id && counter.increment_value !== void 0) {
              statements.push(
                env.DB.prepare(
                  `INSERT INTO user_counters (sub, key, event_id, increment_value) 
									 VALUES (?, ?, ?, ?) 
									 ON CONFLICT(sub, key, event_id) DO NOTHING`
                ).bind(sub, counter.key, counter.event_id, counter.increment_value)
              );
            }
          }
        }
        if (statements.length > 0) {
          await env.DB.batch(statements);
        }
        return Response.json({ success: true });
      } catch (e) {
        return new Response("Bad Request", { status: 400 });
      }
    }
    return new Response("Not Found", { status: 404 });
  }
};

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// .wrangler/tmp/bundle-i0yR5D/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default
];
var middleware_insertion_facade_default = src_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-i0yR5D/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof __Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
__name(__Facade_ScheduledController__, "__Facade_ScheduledController__");
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = (request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    };
    #dispatcher = (type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    };
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
