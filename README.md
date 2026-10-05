# Podkop Subscription Sync — OpenWrt 24.x
> **Версии проекта:** **[OpenWrt 24.x — opkg/IPK](https://github.com/Trogvars/podkop-sub-sync-openwrt24)** · [OpenWrt 25.x — apk/APK](https://github.com/Trogvars/podkop-sub-sync-openwrt25)
> **История изменений:** [CHANGES.md](CHANGES.md)

Версия автоматического синхронизатора VPN-подписки для **Podkop + sing-box**, адаптированная специально для OpenWrt 24.x.

Главные отличия этой ветки:

- пакетный менеджер `opkg`;
- формат пакета `.ipk`;
- совместимость с OpenWrt 24.x;
- не используется `curl --compressed`;
- поддерживаются урезанные сборки curl/libcurl без встроенной поддержки gzip/brotli decompression.

## Что делает программа

`podkop-sub-sync` автоматически поддерживает актуальный список рабочих VPN-серверов в Podkop URLTest.

Программа:

1. Скачивает VPN-подписку.
2. Поддерживает:
   - обычный текст;
   - Base64;
   - gzip;
   - Base64 + gzip.
3. Извлекает:
   - VLESS;
   - Trojan;
   - Shadowsocks.
4. Фильтрует отключённые протоколы.
5. При необходимости исключает XHTTP.
6. Применяет фильтрацию стран: whitelist через `include_country` и blacklist через `exclude_country`.
7. Реально проверяет каждую оставшуюся ноду через временный sing-box и измеряет время доступа.
8. Если задан `precheck_max_nodes`, оставляет только X самых быстрых рабочих нод.
9. Стабилизирует выбранный список и сравнивает его по SHA256.
10. Обновляет Podkop только если список изменился.
11. После обновления проверяет сгенерированный sing-box config.
12. При ошибке выполняет rollback.
13. После успешной синхронизации Podkop самостоятельно выбирает самый быстрый сервер через URLTest.

## Зачем это нужно

Subscription-провайдер может менять:

- IP;
- hostname;
- UUID;
- пароль;
- transport;
- TLS параметры;
- список серверов;
- страну;
- доступность отдельных нод.

Без автоматизации приходится вручную:

- открывать subscription;
- искать новые ссылки;
- удалять умершие серверы;
- копировать их в Podkop;
- проверять доступность;
- следить за изменениями.

`podkop-sub-sync` делает это автоматически.

## Схема работы

```text
Subscription URL
       |
       v
Download
       |
       v
Decode Base64/gzip
       |
       v
Protocol filter
       |
       v
XHTTP filter
       |
       v
Country include/exclude filter
       |
       v
Proxy precheck + latency
       |
       v
Working nodes
       |
       v
Keep fastest X
       |
       v
Stable selected list
       |
       v
SHA256
       |
       +---- same ----> no Podkop restart
       |
       v
Update URLTest
       |
       v
Restart Podkop
       |
       v
sing-box check
       |
       +---- fail ----> rollback
       |
       v
Success
```

## Почему существует отдельная ветка для 24.x

OpenWrt 24.x отличается от 25.x package infrastructure.

В этой версии используется:

```text
opkg
```

а пакет имеет формат:

```text
.ipk
```

Кроме того, на некоторых 24.x-прошивках curl собран без поддержки автоматической декомпрессии HTTP Content-Encoding.

В таком случае команда:

```sh
curl --compressed ...
```

даёт ошибку:

```text
curl: option --compressed:
the installed libcurl version does not support this
```

Поэтому ветка OpenWrt 24.x **вообще не использует `--compressed`**.

Вместо этого отправляется:

```text
Accept-Encoding: identity
```

Если сервер всё равно вернёт raw gzip, программа определит это через:

```sh
gzip -t
```

и распакует файл самостоятельно.

## Компоненты

### `/usr/bin/podkop-sub-sync`

Основной updater.

Выполняет:

- download;
- Base64/gzip decode;
- protocol filtering;
- XHTTP filtering;
- country include/exclude filtering;
- precheck;
- UCI update;
- Podkop restart;
- sing-box validation;
- rollback.

### `/usr/bin/podkop-sub-precheck`

Проверяет реальную работоспособность proxy.

Для каждой группы нод:

1. формирует временный sing-box config;
2. создаёт отдельный local mixed inbound;
3. привязывает каждый inbound к конкретному outbound;
4. выполняет HTTP request через proxy;
5. сохраняет измеренное время каждой рабочей ноды;
6. после полного теста выбирает заданное число самых быстрых.

### `/usr/bin/podkop-sub-sync-daemon`

Запускает updater периодически.

После успешного запуска ждёт:

```text
interval
```

После ошибки:

```text
retry_interval
```

### `/etc/init.d/podkop-sub-sync`

OpenWrt procd service.

### `/etc/config/podkop-sub-sync`

UCI-конфигурация.

## Требования

До установки должны работать:

- OpenWrt 24.x;
- Podkop;
- sing-box.

Также должен существовать:

```text
/usr/lib/podkop/sing_box_config_facade.sh
```

Installer устанавливает через `opkg`:

```text
curl
jq
ca-bundle
```

## Универсальный bootstrap installer

`install.sh` автоматически определяет версию OpenWrt и выбирает нужную ветку проекта:

```text
OpenWrt 24.* -> podkop-sub-sync-openwrt24 -> install-openwrt24.sh
OpenWrt 25.* -> podkop-sub-sync-openwrt25 -> install-podkop-sub-sync.sh
```

Все аргументы передаются выбранному installer-у без изменений, поэтому одна команда подходит для обеих веток:

```sh
wget -qO- https://raw.githubusercontent.com/Trogvars/podkop-sub-sync-openwrt24/main/install.sh \
  | sh -s -- \
      --max-nodes 20
```

Можно одновременно передавать `--url`, `--interval`, `--max-nodes`, `--include`, `--exclude`, `--with-xhttp` и `--no-start`.

При запуске bootstrap выводит определённую версию OpenWrt и выбранный репозиторий. Для версий, отличных от 24.x и 25.x, установка останавливается с ошибкой.

> `install.sh` в обоих репозиториях одинаковый: даже если запустить ссылку из ветки 24.x на OpenWrt 25.x (или наоборот), он скачает правильную ветку.

## XHTTP / sing-box-extended

XHTTP отключён по умолчанию. Чтобы использовать VLESS Reality XHTTP, нужны **оба** компонента:

1. **sing-box-extended**

```sh
wget -O /tmp/sb-ext.sh https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh
sh /tmp/sb-ext.sh
```

Вручную этот внешний installer интерактивный. В `podkop-sub-sync` 1.3.2 его запуск автоматизирован: выбирается последний стабильный релиз и рекомендуемый для роутера формат установки.

2. **XHTTP patch для Podkop**

```sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh
sh /tmp/patch.sh
```

Патч добавляет обработчик `xhttp)` в `/usr/lib/podkop/sing_box_config_facade.sh` и исправляет совместимость Podkop с extended-версией sing-box.

После обновления Podkop патч может быть перезаписан, поэтому его нужно применить повторно.

Проверка:

```sh
sing-box version
grep -n 'xhttp)' /usr/lib/podkop/sing_box_config_facade.sh
```

### Автоматическое восстановление XHTTP-зависимостей

Начиная с версии **1.3.2**, если в конфиге установлено:

```text
option allow_xhttp '1'
```

то и installer, и `/usr/bin/podkop-sub-sync` сами проверяют необходимые компоненты.

Если `sing-box-extended` отсутствует, автоматически:

1. скачивается installer `EikeiDev/OpenWRT-sing-box-extended`;
2. выбирается **первый стабильный релиз** (последний стабильный в списке);
3. выбирается **рекомендуемый installer-ом формат** для конкретного роутера;
4. после установки повторно проверяется `sing-box version`.

Если Podkop не содержит обработчик `xhttp)`, автоматически скачивается и применяется `moix89/podkop-xhttp-patch`.

Ручной ввод и TTY для этой процедуры больше не требуются.

Для автоматической установки и проверки XHTTP-стека используйте:

```text
--with-xhttp
```

Пример:

```sh
wget -qO- https://raw.githubusercontent.com/Trogvars/podkop-sub-sync-openwrt24/main/install.sh \
  | sh -s -- \
      --url 'https://example.com/sub/xxxxx' \
      --interval 86400 \
      --exclude RU \
      --with-xhttp
```

При `allow_xhttp=1` updater автоматически восстанавливает XHTTP-зависимости **до скачивания подписки**: при отсутствии ставит `sing-box-extended`, затем при необходимости применяет Podkop XHTTP patch и только после успешной проверки продолжает синхронизацию.
## Установка одной командой

На OpenWrt BusyBox `ash` лучше использовать pipe, а не bash process substitution.

Не рекомендуется:

```sh
sh <(wget -O - URL)
```

Рекомендуется:

```sh

wget -qO- https://raw.githubusercontent.com/Trogvars/podkop-sub-sync-openwrt24/main/install.sh \
    | sh -s -- \
        --url 'https://example.com/sub/xxxxx' \
        --interval 86400 \
        --exclude RU
```

Несколько стран:

```sh
wget -qO- https://raw.githubusercontent.com/Trogvars/podkop-sub-sync-openwrt24/main/install.sh \
    | sh -s -- \
        --url 'https://example.com/sub/xxxxx' \
        --interval 86400 \
        --exclude RU \
        --exclude UZ
```

## Локальная установка

```sh
chmod +x install-openwrt24.sh
```

```sh
./install-openwrt24.sh \
    --url 'https://example.com/sub/xxxxx' \
    --interval 86400 \
    --exclude RU
```

Installer:

- проверяет `opkg`;
- проверяет Podkop;
- проверяет sing-box;
- выполняет `opkg update`;
- устанавливает зависимости;
- делает backup существующих файлов;
- устанавливает скрипты;
- создаёт/сохраняет UCI config;
- включает procd service;
- запускает daemon.

## Конфигурация

Пример:

```text
config sync 'main'
        option enabled '1'
        option url 'https://example.com/sub/xxxxx'
        option target 'main'

        option interval '86400'
        option retry_interval '900'

        option user_agent 'podkop-sub-sync-openwrt24/1.3.2'
        option send_hwid '0'
        option allow_xhttp '0'

        option enable_vless '1'
        option enable_trojan '1'
        option enable_ss '1'

        # whitelist: оставить только указанные страны
        # list include_country 'RU'

        # blacklist: исключить указанные страны
        # list exclude_country 'RU'

        option precheck_enabled '1'
        option precheck_url 'https://www.gstatic.com/generate_204'
        option precheck_http_code '204'
        option precheck_connect_timeout '3'
        option precheck_timeout '7'
        option precheck_batch_size '6'
        option precheck_base_port '39000'
        option precheck_min_nodes '3'
        option precheck_min_percent '20'
        option precheck_max_nodes '20'
```

## Основные параметры

### Subscription URL

```sh
uci set podkop-sub-sync.main.url='https://example.com/sub/...'
uci commit podkop-sub-sync
```

### Включение

```sh
uci set podkop-sub-sync.main.enabled='1'
uci commit podkop-sub-sync
```

### Интервал

```text
option interval '86400'
```

24 часа.

### Повтор после ошибки

```text
option retry_interval '900'
```

15 минут.

### Протоколы

```text
option enable_vless '1'
option enable_trojan '1'
option enable_ss '1'
```

### XHTTP

```text
option allow_xhttp '0'
```

По умолчанию XHTTP исключается.

### Фильтрация стран: `include_country` и `exclude_country`

`include_country` работает как **whitelist**. Если указан хотя бы один `include_country`, в список попадут только ноды с флагами этих стран.

Например, оставить только российские серверы:

```text
list include_country 'RU'
```

Это удобно для отдельного Podkop-конфига, который должен направлять выбранный трафик только через РФ.

Можно разрешить несколько стран — они объединяются по логике OR:

```text
list include_country 'RU'
list include_country 'KZ'
```

Тогда останутся ноды RU **или** KZ.

`exclude_country` работает как blacklist:

```text
list exclude_country 'RU'
list exclude_country 'UZ'
```

Порядок обработки:

```text
protocols -> XHTTP -> include_country -> exclude_country -> precheck
```

Если одна страна одновременно указана в `include_country` и `exclude_country`, **exclude имеет приоритет**.

При активном `include_country` ноды без подходящего emoji-флага страны удаляются. Фильтрация выполняется по emoji-флагу в fragment/name VPN-ссылки.

Настройка через UCI:

```sh
uci -q delete podkop-sub-sync.main.include_country
uci add_list podkop-sub-sync.main.include_country='RU'
uci commit podkop-sub-sync
/etc/init.d/podkop-sub-sync restart
```

Или сразу при установке:

```sh
wget -qO- https://raw.githubusercontent.com/Trogvars/podkop-sub-sync-openwrt24/main/install.sh \
  | sh -s -- \
      --url 'https://example.com/sub/xxxxx' \
      --include RU
```

Параметр `--include` можно указывать несколько раз.
### Precheck

```text
option precheck_enabled '1'
```

Проверочный URL:

```text
option precheck_url 'https://www.gstatic.com/generate_204'
```

Ожидаемый код:

```text
option precheck_http_code '204'
```

Timeout:

```text
option precheck_connect_timeout '3'
option precheck_timeout '7'
```

Batch size:

```text
option precheck_batch_size '6'
```

Минимальные safety thresholds:

```text
option precheck_min_nodes '3'
option precheck_min_percent '20'
```

### Ограничение числа рабочих нод: `precheck_max_nodes`

После полной проверки доступности скрипт знает время ответа каждой успешно прошедшей ноды.

```text
option precheck_max_nodes '20'
```

означает: протестировать все кандидаты, затем оставить только **20 самых быстрых рабочих нод**.

```text
option precheck_max_nodes '0'
```

отключает ограничение и сохраняет все рабочие ноды.

Порядок работы:

```text
all candidates
      ↓
full availability test
      ↓
working nodes + measured latency
      ↓
sort by response time
      ↓
keep fastest X
      ↓
stable URI sort
      ↓
Podkop URLTest
```

Параметры `precheck_min_nodes` и `precheck_min_percent` проверяются **до** ограничения Top X. Например, если работают 45 из 60 нод, safety-проверка видит все 45, а при `precheck_max_nodes=20` в Podkop попадут 20 самых быстрых.

После выбора Top X URI сортируются стабильно. Поэтому изменение только порядка измеренных задержек не вызывает лишний restart Podkop; SHA256 меняется, когда меняется фактический состав выбранных нод.

В итоговом логе precheck отображаются:

```text
Working     : 45
Selected    : 20
Fastest     : 187ms
Cutoff      : 841ms
```

Настройка через UCI:

```sh
uci set podkop-sub-sync.main.precheck_max_nodes='20'
uci commit podkop-sub-sync
/etc/init.d/podkop-sub-sync restart
```

Или при установке:

```sh
--max-nodes 20
```
## Проверка

Ручной запуск:

```sh
/usr/bin/podkop-sub-sync
```

Логи:

```sh
logread | grep podkop-sub-sync
```

Статус:

```sh
ubus call service list '{"name":"podkop-sub-sync"}'
```

Процессы:

```sh
ps w | grep '[p]odkop-sub-sync'
```

## Управление сервисом

```sh
/etc/init.d/podkop-sub-sync enable
/etc/init.d/podkop-sub-sync start
```

Перезапуск:

```sh
/etc/init.d/podkop-sub-sync restart
```

Остановка:

```sh
/etc/init.d/podkop-sub-sync stop
```

## Сборка IPK

Для OpenWrt 24.x используется SDK соответствующей версии.

Структура проекта:

```text
podkop-sub-sync-openwrt24/
├── README.md
├── install.sh
├── install-openwrt24.sh
├── build-ipk.sh
└── package/
    ├── Makefile
    └── files/
```

Сборка:

```sh
./build-ipk.sh /path/to/openwrt-sdk-24.10.x
```

Или вручную:

```sh
cp -a package /path/to/sdk/package/podkop-sub-sync

cd /path/to/sdk

./scripts/feeds update -a
./scripts/feeds install -a

echo 'CONFIG_PACKAGE_podkop-sub-sync=m' >> .config
make defconfig

make package/podkop-sub-sync/{clean,compile} V=s
```

Найти пакет:

```sh
find bin -name 'podkop-sub-sync_*.ipk'
```

## Установка IPK

```sh
opkg install ./podkop-sub-sync_1.3.2-1_all.ipk
```

Пакет имеет:

```makefile
PKGARCH:=all
```

поскольку содержит только shell/UCI-файлы.

## Обновление IPK

После изменения кода увеличьте:

```makefile
PKG_RELEASE:=2
```

Соберите новый пакет и установите:

```sh
opkg install ./podkop-sub-sync_1.3.2-2_all.ipk
```

UCI-файл:

```text
/etc/config/podkop-sub-sync
```

объявлен как `conffile`, поэтому пользовательские настройки сохраняются при обновлении пакета.

## Rollback

Перед изменением:

```text
/etc/config/podkop
```

сохраняется.

Если новый sing-box config не проходит validation или сервис не запускается, предыдущая конфигурация восстанавливается.

## Пример работы

Subscription:

```text
102 links
```

После удаления XHTTP:

```text
75
```

После исключения RU:

```text
66
```

Precheck:

```text
Working: 41
Failed: 25
```

При `precheck_max_nodes=20` выбираются 20 самых быстрых рабочих нод:

```text
Selected: 20
```

Именно эти 20 нод записываются в Podkop URLTest. Далее Podkop продолжает выбирать лучший сервер уже внутри этого сокращённого набора.

## Отличия от версии OpenWrt 25.x

OpenWrt 24.x:

```text
opkg
.ipk
no curl --compressed
```

OpenWrt 25.x:

```text
apk
.apk
новая package infrastructure
```

Рекомендуется использовать отдельную ветку проекта для каждой версии OpenWrt.

## Лицензия

MIT
