# Лабораторная работа № 2 — симуляция SCR1

## Задание: вариант 10

| Параметр | Значение |
| --- | --- |
| Исключение | Breakpoint |
| Тест | `dependencies/riscv-tests/isa/rv32mi/sbreak.S` |
| Reset Vector | `0x400` |
| Trap Vector | `0xA00` |
| Сообщение обработчика | `break break` |
| Рабочая ветка | `lab_scr1_sim` |

## Подготовка

Проект находится в `D:\Coding\risk-v\scr1-sim`.
Отчёт и сохранённые результаты находятся в `lab/`.

Для сборки используется Docker-образ `scr1-lab` на Ubuntu 24.04:

- GNU Make 4.3 и G++ 13.3.0;
- Verilator 5.052, собранный из исходников;
- Syntacore GCC 12.2.1 из SC-DT 2023.11 с поддержкой TLS.

Подмодули инициализированы на версиях, закреплённых в репозитории.
Исходники ядра, список тестов, обработчик и linker-скрипты по варианту
пока не изменялись.

## Сборка и запуск

При запущенном Docker Desktop в режиме Linux-контейнеров, из PowerShell:

```powershell
cd D:\Coding\risk-v\scr1-sim
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" scr1-lab sh -c "make clean && make"
```

Образ уже собран. После правок исходников достаточно `docker run`.
Для первой установки на другом компьютере или после изменения `Dockerfile`:

```powershell
docker build -t scr1-lab .
```

Папка проекта подключается к `/work`, результаты появляются в `build`
на Windows. Параметр `--rm` удаляет завершившийся контейнер, сохраняя образ
и файлы в подключённой папке.

## Проверка исходного проекта

Команда `make clean && make` выполнена в Docker с исходными настройками
`CFG=MAX`, `BUS=AHB`, `TRACE=0`. Результат — **224 из 224 тестов PASS**.
Список выполненных тестов совпал со списком запрошенных.

| Набор | Количество тестов |
| --- | ---: |
| RISC-V ISA | 56 |
| RISC-V Compliance | 84 |
| RISC-V Architectural | 80 |
| isr_sample, CoreMark, Dhrystone, hello | 4 |

Сохранены результаты этого запуска:

- [test_results.txt](baseline/test_results.txt) — статусы тестов;
- [sim_results.txt](baseline/sim_results.txt) — вывод симуляции;
- [test_info.txt](baseline/test_info.txt) — список тестов;
- [environment.txt](baseline/environment.txt) — версии инструментов и коммиты;
- [sbreak.dump](baseline/sbreak.dump) — исходный дизассемблер теста;
- [image.txt](baseline/image.txt) — идентификатор проверенного Docker-образа.

Дамп подтверждает исходные адреса: `_start = 0x200`,
`trap_vector = 0x1C0`. По варианту они должны стать `0x400` и `0xA00`.

CoreMark запускается с `ITERATIONS=1`: контрольные суммы совпали с эталоном,
но он сообщает о длительности меньше 10 секунд и печатает `Errors detected`.
Окружение SCR1 отмечает тест как PASS; этот короткий запуск не является
действительным измерением производительности CoreMark.

## Следующие шаги

1. Оставить только `sbreak.S` и проверить его отдельно.
2. Добавить вывод `break break` при исключении Breakpoint, сохранив проверки теста.
3. Настроить векторы и размещение кода по адресам `0x400` и `0xA00`.
4. Выполнить симуляцию с трассировкой и сформировать VCD для GTKWave.
5. Сохранить итоговые `test_results.txt`, `*.dump`, `trace_mprf_diff_*.log`
   и `trace_csr_*.log` в `results/`.
6. Дополнить отчёт и закоммитить изменения.

Источники инструментов:
[Verilator](https://verilator.org/guide/latest/install.html),
[Syntacore SC-DT](https://syntacore.com/tools/development-tools/previous-releases).
