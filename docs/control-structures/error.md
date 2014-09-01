---
layout: api-command
language: Ruby
permalink: api/ruby/error/
command: error
---

# Command syntax #

{% apibody %}
r.error(message) &rarr; error
{% endapibody %}

# Description #

Throw a runtime error. If called with no arguments inside the second argument to `default`, re-throw the current error.

__Example:__ Iron Man can't possibly have lost a battle:

```rb
r.table('marvel').get('IronMan').do { |ironman|
    r.branch(ironman[:victories] < ironman[:battles],
    r.error('impossible code path'),
    ironman)
}.run(conn)
```
