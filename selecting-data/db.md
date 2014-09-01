---
layout: api-command
language: Ruby
permalink: api/ruby/db/
command: db
related_commands:
    table: table/
    db_list: db_list/
---


# Command syntax #

{% apibody %}
r.db(db_name) &rarr; db
{% endapibody %}

# Description #

Reference a database.

__Example:__ Before we can query a table we have to select the correct database.

```rb
r.db('heroes').table('marvel').run(conn)
```


