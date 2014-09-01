---
layout: api-command
language: Ruby
permalink: api/ruby/get_field/
command: '[] (get_field)'
---

# Command syntax #

{% apibody %}
sequence[attr] &rarr; sequence
singleSelection[attr] &rarr; value
object[attr] &rarr; value
{% endapibody %}

# Description #

Get a single field from an object. If called on a sequence, gets that field from every
object in the sequence, skipping objects that lack it.

__Example:__ What was Iron Man's first appearance in a comic?

```rb
r.table('marvel').get('IronMan')[:first_appearance].run(conn)
```


