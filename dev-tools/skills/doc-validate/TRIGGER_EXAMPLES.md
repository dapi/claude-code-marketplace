# Trigger Examples for doc-validate skill

## Команды

### /doc:lint
```
/doc:lint
проверь форматирование документации
doc lint
check doc formatting
найди битые ссылки
broken links check
```

### /doc:links
```
/doc:links
проверь граф документации
find orphan documents
orphan docs
dead-end documents
check navigation
```

### /doc:terms (Session 2)
```
/doc:terms
проверь терминологию
check glossary consistency
найди синонимы
```

### /doc:viewpoints (Session 2)
```
/doc:viewpoints
проверь артефакты
check modeling standards
missing state diagrams
threat model check
```

### /doc:contradictions (Session 3)
```
/doc:contradictions
найди противоречия
find conflicts
конфликтующие требования
```

### /doc:gaps (Session 3)
```
/doc:gaps
найди пробелы
missing coverage
incomplete documentation
```

### /doc:review
```
/doc:review
полный аудит документации
full doc review
validate all docs
проверь всю документацию
```

## Комбинированные примеры

```
# Перед коммитом
/doc:lint перед пушем

# После добавления новой фичи
проверь документацию на полноту

# Подготовка к релизу
/doc:review с отчётом

# Найти проблемы
какие проблемы в документации?
что не так с документацией?
```

## Не активирует skill

```
# Общие вопросы о документации
как писать документацию?
что такое ADR?
```
