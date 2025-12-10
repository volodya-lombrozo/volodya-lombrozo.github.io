---
layout: post
title: "Thread-Safety Pitfalls in XML Processing"
excerpt: "Or how to shoot yourself in the foot with Java Streams. Learn thread-safety pitfalls in Java’s DOM and Stream APIs — and practical strategies to avoid concurrency issues."
date: 2025-02-19
---

# Thread-Safety Pitfalls in XML Processing

Do you think the method `children()` below is thread-safe?

```java
import java.util.stream.Stream;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

public final class SafeXml {
  
  private final Node node;
  
  SafeXml(final Node node) {
    this.node = node.cloneNode(true);
  }

  public Stream<SafeXml> children() {
    NodeList nodes = this.node.getChildNodes();
    int length = nodes.getLength();
    return Stream.iterate(0, idx -> idx + 1)
      .limit(length)
      .map(nodes::item)
      .map(SafeXml::new);
  }
}
```

Of course, since I’m asking this question, the answer is **no**.
For those who haven’t had the _pleasure_ of working with XML in Java (yes, it’s
still alive), the `org.w3c.dom` package is not thread-safe.
There are no guarantees even for just reading data from an XML document in
a multi-threaded environment.

For more background, here’s
a [good Stack Overflow thread](https://stackoverflow.com/questions/3439485/java-and-xml-jaxp-what-about-caching-and-thread-safety)
on the topic.

So, if you decide to run `children()` method in parallel, sooner or later,
you will encounter something like this:

```java
Caused by:java.lang.NullPointerException
    at java.xml/com.sun.org.apache.xerces.internal.dom.CoreDocumentImpl.getNodeListCache(CoreDocumentImpl.java:2283)
    at java.xml/com.sun.org.apache.xerces.internal.dom.ParentNode.nodeListGetLength(ParentNode.java:690)
    at java.xml/com.sun.org.apache.xerces.internal.dom.ParentNode.getLength(ParentNode.java:720)
    at SafeXml.children(SafeXml.java)
```

(Java uses Xerces as the default implementation of the DOM API.)

Let's fix it then?

## Attempt #1: Synchronization to the Rescue?

Being seasoned developers, we do what we do best: we Google it. And we
find [this answer](https://stackoverflow.com/questions/10550900/concurrency-and-reusage-of-org-w3c-dom-node)
on StackOverflow:

> your only choice is to synchronize all access to the Document/Nodes

Alright, let’s follow the advice and add some synchronization:

```java
public Stream<SafeXml> children(){
  synchronized (this.node){
    NodeList nodes = this.node.getChildNodes();
    int length = nodes.getLength();
    return Stream.iterate(0, idx -> idx + 1)
    .limit(length)
    .map(nodes::item)
    .map(SafeXml::new);
  }
}
```

Great! Now, let's test it — multiple threads calling `children()` in parallel.
The test passes... until the 269th run, when the same `NullPointerException`
pops up again. Wait, what?! Didn’t we **just** add synchronization?

## Attempt #2: Synchronize on the Document

It turns out that each DOM `Node` has internal shared state
(likely a cache) across different `Node` instances. 
In other words, synchronizing on a single node isn’t enough — we have to lock
the entire document.

So, we tweak our code:

```java
public final class SafeXml {

  private final Document doc;
  private final Node node;

  SafeXml(final Document doc, final Node node) {
    this.doc = doc;
    this.node = node.cloneNode(true);
  }

  public Stream<SafeXml> children() {
    synchronized (this.doc) {
      NodeList nodes = this.node.getChildNodes();
      int length = nodes.getLength();
      return Stream.iterate(0, idx -> idx + 1)
        .limit(length)
        .map(nodes::item)
        .map(n -> new SafeXml(this.doc, n));
    }
  }
}
```

We might not like this solution, but it’s the only way to make it work.
The DOM API is designed to be single-threaded, and making it thread-safe would
introduce a significant performance overhead for single-threaded applications.
So, it’s a trade-off we have to live with.

Eventually, I ran the tests again, and they passed consistently...
Until the 5518th run, when I got hit with the same `NullPointerException`.
Seriously? What now?!

## Attempt #3: The Stream API Strikes Back

The problem was hiding in plain sight:

```java
return Stream.iterate(0, idx -> idx + 1)
  .limit(length)
  .map(nodes::item)
  .map(n->new SafeXml(this.doc,n));
```

I like the **Java Stream API** — it’s elegant, concise, and powerful.
But it’s also **lazy**, meaning that the actual iteration doesn’t happen inside
`children()` method. Instead, it happens **later**,
when the stream is actually consumed when a terminal operation (like `collect()`)
is called on it.
This means that by
the time the real iteration happens, synchronization no longer applies.

So, what’s the fix? Force eager evaluation before returning the stream.
Here’s how:

### Option 1: Collect to a List

```java
return Stream.iterate(0, idx -> idx + 1)
  .limit(length)
  .map(nodes::item)
  .map(n->new SafeXml(this.doc,n))
  .collect(Collectors.toList()) // Here we force eager evaluation
  .stream();                    // and return a new stream
```

### Option 2: Use `Stream.Builder`

```java
public Stream<SafeXml> children(){
  synchronized (this.doc){
    NodeList nodes = this.node.getChildNodes();
    int length = nodes.getLength();
    Stream.Builder<SafeXml> builder = Stream.builder();
    for(int i = 0; i < length; i++){
      Node n = nodes.item(i);
      builder.accept(new SafeXml(this.doc,n));
    }
    return builder.build();
  }
}
```

### Option 3: Use `ArrayList`

```java
public Stream<SafeXml> children(){
  synchronized (this.doc){
    NodeList nodes = this.node.getChildNodes();
    int length = nodes.getLength();
    List<SafeXml> children = new ArrayList<>(length);
    for(int i = 0; i < length; i++){
      Node n = nodes.item(i);
      children.add(new SafeXml(this.doc,n));
    }
    return children.stream();
  }
}
```

According to benchmarks, the `Stream.Builder` approach is the fastest:

```shell
Benchmark                        Mode  Cnt  Score   Error  Units
SafeXmlBenchmark.array           avgt       0.780          us/op
SafeXmlBenchmark.collect_stream  avgt       1.360          us/op
SafeXmlBenchmark.stream_builder  avgt       0.631          us/op
```

## Final Thoughts

So, we’ve finally fixed the issue. The main takeaways:

- DOM nodes are not thread-safe. If you need to process them in parallel,
  synchronize on the entire document.
- Java Streams are lazy—if you use them in a multi-threaded context,
  be careful about where they’re evaluated.
- Tests are your best friends, but sometimes they pass 5000 times before
  failing.

And this wasn’t just a theoretical problem — this exact issue was found and
fixed in a real project.
If you're curious, you can check out the actual fix
in [this](https://github.com/volodya-lombrozo/xnav/pull/62) pull request.

Happy coding! And watch out for those lazy streams!

This article was also published on [dzone.com](https://dzone.com/articles/thread-safety-pitfalls-in-xml-processing).
