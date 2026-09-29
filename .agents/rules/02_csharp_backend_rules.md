# Rule 02: C# & ASP.NET Backend Development Standards

## 1. Framework & Pipeline Guidelines
- **Target Framework:** .NET Framework 4.7.2 with OWIN startup pipeline (`IAppBuilder`).
- **Web API Conventions:**
  - Controllers must inherit from `ApiController` and reside under `Controllers/Api/`.
  - Use attribute routing: `[RoutePrefix("api/v1/resource")]` with explicit HTTP verb attributes `[HttpGet]`, `[HttpPost]`, `[HttpPut]`, `[HttpDelete]`.
  - Always return `IHttpActionResult` using helper methods: `Ok(data)`, `NotFound()`, `BadRequest(ModelState)`, or `Content(HttpStatusCode.Conflict, errorDto)`.

## 2. Asynchronous Programming (`async/await`)
- All I/O operations (Database access, external HTTP calls to HitPay, SignalR hub invocations) must use `async Task<T>` and `await`.
- Never use `.Result` or `.Wait()` on asynchronous tasks, as this leads to thread starvation and deadlocks in ASP.NET request synchronization contexts.
- Use `ConfigureAwait(false)` in non-UI service/library methods.

## 3. Layered Architecture & Responsibilities
- **Controllers:** Responsible only for request parsing, model validation, and invoking services. No raw SQL or complex business calculations in controllers.
- **Services:** Implement business rules, coordinate repository transactions, invoke payment gateways, and trigger SignalR notifications.
- **Repositories:** Abstract database interactions using parameterized ADO.NET or micro-ORMs. Handle connection lifetimes using `using (var conn = ...)` statements.
- **DTOs vs. Entities:** Never expose internal database entities directly to the client. Always map to and from DTOs.

## 4. Error Handling & Logging
- Use a global exception filter or OWIN middleware to intercept unhandled exceptions and return a standardized JSON error response:
  ```json
  {
    "success": false,
    "message": "A descriptive error message",
    "errorCode": "INVALID_INVENTORY",
    "timestamp": "2026-09-25T14:00:00Z"
  }
  ```
- Sensitive details (stack traces, SQL errors, inner exceptions) must never be sent to the client in production responses.

## 5. Backend Logic Authority Mandate
- **All Core Workloads Reside in C#:** All product filtering, pricing calculations, inventory decrementing, order fulfillment status transitions, and authentication verifications MUST be implemented in C# backend classes (Web API controllers, services, and repositories).
- **Prohibition of JS Backend Workarounds:** Do not build fake JS backends, dummy in-browser arrays pretending to be the database, or NodeJS microservices. If new business capabilities are needed, add or extend the appropriate C# service, repository, or Web API controller.
