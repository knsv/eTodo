{application, eLog,
 [
  {description, "Simple logging application"},
  {vsn, "0.9.0"},
  {registered, [eLog, eLogWriter]},
  {applications, [
                  kernel,
                  stdlib
                 ]},
  {mod, { eLog_app, []}},
  {env, []}
 ]}.