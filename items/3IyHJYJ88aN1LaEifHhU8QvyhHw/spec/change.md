`_work/api.tl` `error_of`: when the response body is JSON with a
`message` and an `errors` array, append `: <message>` and the first
`errors[].message` to the error string it returns — one place, every
caller. `_work/api_test.tl`: a 422 body with `errors[0].message = "No
commits between main and x"` → the returned error contains that
sentence; a non-JSON body → today's string.
