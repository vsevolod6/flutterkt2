import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

enum TodoPriority { low, medium, high }
enum TodoFilter { all, active, done }

// Модель задачи
class Todo {
  final String id;
  final String title;
  final String text;
  final bool isDone;
  final TodoPriority priority;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    required this.text,
    this.isDone = false,
    this.priority = TodoPriority.medium,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Todo copyWith({
    String? id,
    String? title,
    String? text,
    bool? isDone,
    TodoPriority? priority,
    DateTime? createdAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToDo List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Todo> _todos = [];
  TodoFilter _filter = TodoFilter.all;
  String _query = '';

  void _addTodo(Todo todo) {
    setState(() => _todos.add(todo));
  }

  void _updateTodo(Todo updatedTodo) {
    setState(() {
      final index = _todos.indexWhere((t) => t.id == updatedTodo.id);
      if (index != -1) _todos[index] = updatedTodo;
    });
  }

  void _removeTodo(String id) {
    setState(() => _todos.removeWhere((t) => t.id == id));
  }

  void _toggleDone(Todo todo) {
    _updateTodo(todo.copyWith(isDone: !todo.isDone));
  }

  List<Todo> get _visibleTodos {
    Iterable<Todo> list = _todos;

    // filter
    switch (_filter) {
      case TodoFilter.active:
        list = list.where((t) => !t.isDone);
        break;
      case TodoFilter.done:
        list = list.where((t) => t.isDone);
        break;
      case TodoFilter.all:
        break;
    }

    // search
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) =>
          t.title.toLowerCase().contains(q) ||
          t.text.toLowerCase().contains(q));
    }

    final result = list.toList();

    // sort: undone first, then by priority (high->low), then by createdAt desc
    int prioRank(TodoPriority p) {
      switch (p) {
        case TodoPriority.high:
          return 3;
        case TodoPriority.medium:
          return 2;
        case TodoPriority.low:
          return 1;
      }
    }

    result.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1; // undone first
      final pr = prioRank(b.priority).compareTo(prioRank(a.priority));
      if (pr != 0) return pr;
      return b.createdAt.compareTo(a.createdAt);
    });

    return result;
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Color _priorityColor(TodoPriority p, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (p) {
      case TodoPriority.low:
        return scheme.primary.withOpacity(0.35);
      case TodoPriority.medium:
        return scheme.tertiary.withOpacity(0.55);
      case TodoPriority.high:
        return scheme.error.withOpacity(0.75);
    }
  }

  String _priorityLabel(TodoPriority p) {
    switch (p) {
      case TodoPriority.low:
        return 'Низкий';
      case TodoPriority.medium:
        return 'Средний';
      case TodoPriority.high:
        return 'Высокий';
    }
  }

  String _filterLabel(TodoFilter f) {
    switch (f) {
      case TodoFilter.all:
        return 'Все';
      case TodoFilter.active:
        return 'Активные';
      case TodoFilter.done:
        return 'Выполненные';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleTodos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои задачи'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Search + Filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Поиск по задачам...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TodoFilter>(
                        value: _filter,
                        decoration: const InputDecoration(
                          labelText: 'Фильтр',
                          border: OutlineInputBorder(),
                        ),
                        items: TodoFilter.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(_filterLabel(f)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _filter = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          // quick toggle: all -> active -> done -> all
                          _filter = switch (_filter) {
                            TodoFilter.all => TodoFilter.active,
                            TodoFilter.active => TodoFilter.done,
                            TodoFilter.done => TodoFilter.all,
                          };
                        });
                      },
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Цикл'),
                    )
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Text('Нет задач. Нажмите "+" чтобы добавить.'),
                  )
                : (items.isEmpty
                    ? const Center(child: Text('Ничего не найдено по фильтру/поиску.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final todo = items[index];
                          return Dismissible(
                            key: Key(todo.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              // нужно найти реальный индекс в _todos, чтобы корректно откатить
                              final originalIndex = _todos.indexWhere((t) => t.id == todo.id);
                              _removeTodo(todo.id);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Задача "${todo.title}" удалена'),
                                  action: SnackBarAction(
                                    label: 'Отмена',
                                    onPressed: () {
                                      if (originalIndex == -1) return;
                                      setState(() {
                                        _todos.insert(originalIndex, todo);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 10,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _priorityColor(todo.priority, context),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                title: Text(
                                  todo.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: todo.isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (todo.text.trim().isNotEmpty)
                                        Text(
                                          todo.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Chip(
                                            label: Text('Приоритет: ${_priorityLabel(todo.priority)}'),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          Chip(
                                            label: Text('Создано: ${_formatDate(todo.createdAt)}'),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: todo.isDone,
                                  onChanged: (_) => _toggleDone(todo),
                                ),
                                onTap: () async {
                                  final updatedTodo = await Navigator.push<Todo>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditTodoScreen(todo: todo),
                                    ),
                                  );
                                  if (updatedTodo != null) _updateTodo(updatedTodo);
                                },
                              ),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTodo = await Navigator.push<Todo>(
            context,
            MaterialPageRoute(builder: (context) => const AddTodoScreen()),
          );
          if (newTodo != null) _addTodo(newTodo);
        },
        tooltip: 'Добавить задачу',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Экран добавления новой задачи
class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({super.key});

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  TodoPriority _priority = TodoPriority.medium;

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _priorityLabel(TodoPriority p) {
    switch (p) {
      case TodoPriority.low:
        return 'Низкий';
      case TodoPriority.medium:
        return 'Средний';
      case TodoPriority.high:
        return 'Высокий';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая задача'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название задачи *',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TodoPriority>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Приоритет',
                border: OutlineInputBorder(),
              ),
              items: TodoPriority.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(_priorityLabel(p)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Название обязательно')),
                    );
                    return;
                  }

                  final newTodo = Todo(
                    id: const Uuid().v4(),
                    title: title,
                    text: _textController.text.trim(),
                    priority: _priority,
                  );

                  Navigator.pop(context, newTodo);
                },
                child: const Text('Сохранить задачу'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Экран редактирования задачи
class EditTodoScreen extends StatefulWidget {
  final Todo todo;

  const EditTodoScreen({super.key, required this.todo});

  @override
  State<EditTodoScreen> createState() => _EditTodoScreenState();
}

class _EditTodoScreenState extends State<EditTodoScreen> {
  late TextEditingController _titleController;
  late TextEditingController _textController;
  late TodoPriority _priority;
  late bool _isDone;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _textController = TextEditingController(text: widget.todo.text);
    _priority = widget.todo.priority;
    _isDone = widget.todo.isDone;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _priorityLabel(TodoPriority p) {
    switch (p) {
      case TodoPriority.low:
        return 'Низкий';
      case TodoPriority.medium:
        return 'Средний';
      case TodoPriority.high:
        return 'Высокий';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать задачу'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название задачи *',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TodoPriority>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Приоритет',
                border: OutlineInputBorder(),
              ),
              items: TodoPriority.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(_priorityLabel(p)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isDone,
              onChanged: (v) => setState(() => _isDone = v),
              title: const Text('Выполнено'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Название обязательно')),
                    );
                    return;
                  }

                  final updatedTodo = widget.todo.copyWith(
                    title: title,
                    text: _textController.text.trim(),
                    priority: _priority,
                    isDone: _isDone,
                  );

                  Navigator.pop(context, updatedTodo);
                },
                child: const Text('Сохранить изменения'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
