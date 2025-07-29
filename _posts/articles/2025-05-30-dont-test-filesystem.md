# Mock the File System

The article was published on [dzone.com](https://dzone.com/articles/mock-the-file-system)

It happens quite often that our applications need to interact with the file system.  
As a result, some components inevitably depend on it.
When we test such code, we face a choice: mock the file system, or test against the real one?  
There are several opposing views on this.


Most developers avoid using the file system in unit tests.  
Tests that touch the disk are usually treated as an anti‑pattern because they are slow and brittle.

https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices

> Characteristics of good unit tests
> Isolated: Unit tests are standalone, can run in isolation, and have no dependencies on any outside factors, such as a file system or database.

_Unit testing best practices for .NET_

However, the world has changed, and modern file systems are extremely fast and robust.  
This means that, in most cases, we can safely use the actual file system in tests without significant losses in test speed.  
It’s extremely rare nowadays for anyone to experience serious problems because of it.  
So, you might find the idea of using the file system in tests appealing:

https://github.com/objectionary/eo/pull/4113#issuecomment-2820368440
https://www.amazon.com.au/Angry-Tests-Yegor-Bugayenko/dp/B0F54QSHHS

> The file system in modern comuters is as reliable as memeory. We don't mock memory managers-why mock the file system?

_Angry Tests_

Well, it's hard to disagree with this point. Isn't it?  
Although the file system is still slower than memory, we can usually ignore a few milliseconds and use it directly in tests for the sake of simplicity and fast development.
But I totally disagree with this take, and I’ll try to show you that this “simplicity” leads to disappointment—and that it’s still a bad idea to extensively use the file system in tests.

First of all, the slowdown become noticeable as your project grows and accumulates thousands of tests that heavily rely on file system operations.  
At that scale, using the file system can lead to extremely slow test execution.

Also, testing with the file system tends to be verbose.
When we write such tests, we have to account for many corner cases: checking that a file exists, ensuring all directories are created before writing a file, properly opening and closing files, and handling OS-specific differences such as path representations (for example, Unix vs Windows).
Because of this, interacting with the file system typically requires extra checks to ensure nothing fails unexpectedly.
At the code level, this leads to widespread use of `try-catch` blocks (in Java) or explicit `error` handling (in Go).
Even if file system failures are rare, we still have to write boilerplate code to handle these risks—mostly due to how standard libraries are designed.

However, performance and verbosity, aren't the main concerns.  
The deeper issue is much more dangerous—one that can quietly poison your project over time.  
Let’s take a look at the following unit test:


```java
@Tes
void retrievesNextTask(@TempDir Path folder) throws IOException {
   Files.write(
       folder.resolve("tasks.csv"),
       "Task-1\nTask-2\nTask-3".getBytes("UTF-8")
   );

   final TodoList list = new TodoList(folder);

   assertEquals("Task-1", list.nextTask());
   assertEquals("Task-2", list.nextTask());
   assertEquals("Task-3", list.nextTask());
}

```

I hope the example is clear enough.
We saved our to-do list to a CSV file, then our `TodoList` object reads that file from a `folder`, parses it, and allows us to retrieve tasks from it.
So far, there’s nothing wrong.

But things change quickly once we decide to build something on top of `TodoList`.
For example, if the requirements change and we now have to implement an `Employee` class that interacts with `TodoList`:

```java
@Test
void startsWork(@TempDir Path folder) throws IOException {
    Files.write(
        folder.resolve("tasks.csv"),
        "make coffee\nread news\nsend message to a friend".getBytes("UTF-8")
    );
    TodoList list = new TodoList(folder);
    Employee employee = new Employee(list);
    
    String[] tasks = employee.startWork();
    
    Assertions.assertArrayEquals
        new String[]{
            "Working on 'make coffee'",
            "Working on 'read news'",
            "Working on 'send message to a friend'"
        },
        tasks
    );
}
```

Did you notice? I had to initialize `TodoList` again.
To do that, I once more had to create a temporary directory, write a file to it, populate that file, and handle an `IOException`.
And I needed to know how to initialize `TodoList` just to test `Employee`—which isn’t even our concern here.
We've already tested `TodoList`.

Now let’s take it one step further.
We can see that our `Employee` works with a single instance of `TodoList`, which isn’t shared with any other object.
So why not "simplify" the implementation by initializing `TodoList` inside the `Employee` itself?
And now, our code becomes pure magic:

```java

@Test
void startsWork(@TempDir Path folder) throws IOException {
    Files.write(
        folder.resolve("tasks.csv"),
        "make coffee\nread news\nsend message to a friend".getBytes("UTF-8")
    );                                        // We still need it to correctly initialize Employee
    Employee employee = new Employee(folder); // TodoList is created inside the Employee constructor

    String[] tasks = employee.startWork();
    
    Assertions.assertArrayEquals
        new String[]{
            "Working on 'make coffee'",
            "Working on 'read news'",
            "Working on 'send message to a friend'"
        },
        tasks
    );
}
```

If I had shown you this code first, you would have reasonably asked,
“Why do we need to create a strange CSV file just to test `Employee`?”
And that would be a fair question.
When we look at the final code snippet, it’s almost impossible to understand why such a file is necessary for the test.
Most probably, nobody even remembers the file's internal structure.

Of course, this is only a simple example.
In reality, we often have a huge number of entities that depend on each other, and the situation is much worse.

Things deteriorate even further when new developers join your project.
They have no idea about the internals or why they’re supposed to create the same CSV files for every test.
So what do they do?
They simply copy the initialization code from other tests—because that’s how it’s done throughout the project.

After a few more months—or years—almost all of your “unit” tests will somehow rely on a temporary directory:

```
(@TempDir Path folder)
```
_Automtic creation of temporary folder for tests in JUnit_

The next step is usually to create some kind of test harness that handles all the file system setup.
At that point, it becomes extremely hard to go back and solve the problem properly—because we've already invested so much time into it, and technically, it works.
Even if it slows down test execution, some developers are willing to tolerate it simply because, well, _they’re just tests_.

But testing the system becomes painful, because now you have to understand all the internal details and have a solid grasp of the new test harness just to test a small component.
Instead of clear inputs (constructor parameters and method arguments) and observable outputs (return values), you're now dealing with an implicit global state that you must know exactly how to initialize.

https://softwareengineering.stackexchange.com/questions/148108/why-is-global-state-so-evil

> Very briefly, it [global state] makes program state unpredictable.

_Why is Global State so Evil?_

At some point, the tests become so rigid and fragile that changing them feels impossible.
Even top experts who built the system from scratch often can’t fully comprehend what’s going on in their own tests.

So what happens when a test fails—buried under layers of file system setup—and nobody knows how to fix it?
They start ignoring it, or they delete it without even reading it. Touché.

As a result, the project becomes nearly unmaintainable.

### What could we do instead?

If using the file system introduces so many problems, why not just avoid it?
Generally speaking, there’s a straightforward and well-known technique for decoupling components.
The exact approach may vary between languages, but in most cases,
it can be solved by introducing an interface (in Java or Go) or a header file (in C),
and then providing multiple implementations—one real, and one mock:
 
```java
@Test
void startsWorkWithMock()  {
    final TodoList list = new MockList(
        "make coffee",
        "read news",
        "send message to a friend"
    ); // Now, our 'TodoList' is an interface and 'MockList' is an implementation
    final Employee employee = new Employee(list);

    final String[] tasks = employee.startWork();

    Assertions.assertArrayEquals(
        new String[]{
            "Working on 'make coffee'",
            "Working on 'read news'",
            "Working on 'send message to a friend'"
        },
        tasks
    );
}
```

_`TodoList` is an interface now, and we have two implementations: `MockList` and `CsvList`_

Now, we're no longer tied to the file system.
This simple change heals your project and helps you avoid all the traps mentioned above.
As a result, your tests become simpler—no more heavy initialization, just a single line to create a mock object in most cases.
You also eliminate hidden global state in tests, keeping everything isolated and predictable.
This not only speeds up test execution but also significantly improves maintainability.

Thus, even modern file systems still create complications that aren't worth solving.
It's simply better to avoid using them in your tests.
Like any external dependency, the file system should be decoupled from your domain logic.

Put simply, refusing to mock the file system is a costly mistake—one that will inevitably, and quietly, kill your project like a slow, dangerous disease.
It's better to avoid using the file system in your tests.
Stay healthy, and happy coding!
