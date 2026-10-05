# CHANGES

История изменений **Podkop Subscription Sync**.

Версии 24.x и 25.x развиваются синхронно по функциональности. Различия между ветками касаются прежде всего пакетного менеджера, формата пакета и особенностей OpenWrt.

## 1.2.0

### Добавлено

- Новый UCI-параметр whitelist по странам:

```text
list include_country 'RU'
```

- Поддержка нескольких разрешённых стран:

```text
list include_country 'RU'
list include_country 'KZ'
```

  В этом случае сохраняются ноды RU **или** KZ.

- Новый параметр installer-а:

```sh
--include RU
```

  Параметр можно указывать несколько раз.

- Фильтрация стран теперь выполняется в порядке:

```text
protocols -> XHTTP -> include_country -> exclude_country -> precheck
```

- Если страна присутствует одновременно в `include_country` и `exclude_country`, **exclude имеет приоритет**.
- При активном `include_country` ноды без подходящего emoji-флага страны удаляются.
- Добавлена явная ошибка, если whitelist удалил все proxy.
- В README добавлены сценарии использования отдельного RU-only конфига.
- В шапку README добавлены перекрёстные ссылки на проекты OpenWrt 24.x и 25.x.

### Изменено

- Для новых установок пример `exclude_country 'RU'` в дефолтном конфиге теперь закомментирован, чтобы не конфликтовать с `include_country 'RU'`.
- User-Agent обновлён до ветки 1.2.
- Версия OpenWrt package recipe повышена до `1.2.0`.
- Bundle `podkop-sub-sync-openwrt24.tar.gz` пересобран с актуальными README, installer, config и package files.

### Совместимость

Существующий `/etc/config/podkop-sub-sync` при обновлении сохраняется. Новый `include_country` не влияет на старое поведение, пока параметр не добавлен.

---

## 1.1.0

### Добавлено

- Поддержка сценария XHTTP через `sing-box-extended`.
- Новый параметр installer-а:

```sh
--with-xhttp
```

- Installer умеет:
  - проверить наличие `sing-box-extended`;
  - при необходимости запустить installer проекта `EikeiDev/OpenWRT-sing-box-extended`;
  - проверить наличие XHTTP parser-а в Podkop;
  - при необходимости применить `moix89/podkop-xhttp-patch`;
  - включить `allow_xhttp=1`.

- В updater добавлена ранняя проверка XHTTP-зависимостей:
  - если включён XHTTP, но используется обычный sing-box — синхронизация останавливается;
  - если Podkop facade не содержит обработчик `xhttp)` — синхронизация останавливается;
  - проверка выполняется до скачивания subscription и precheck.

- Добавлен bootstrap installer:

```sh
wget -qO- https://raw.githubusercontent.com/Trogvars/podkop-sub-sync-openwrt24/main/install.sh | sh
```

- README дополнен инструкциями по установке `sing-box-extended` и XHTTP patch.
- Package version повышена до `1.1.0`.

### Изменено

- Поддержка OpenWrt 24.x оставлена совместимой с `opkg` и `.ipk`.
- Для загрузки subscription по-прежнему не используется `curl --compressed`.
- Используется:

```text
Accept-Encoding: identity
```

  а raw gzip определяется и распаковывается самостоятельно.

---

## 1.0.0

Первая полноценная версия отдельной ветки для OpenWrt 24.x.

### Основные возможности

- OpenWrt 24.x / `opkg` / `.ipk`.
- Скачивание VPN subscription по URL.
- Поддержка:
  - plain text;
  - Base64;
  - gzip;
  - Base64 + gzip.
- Поддерживаемые proxy-ссылки:
  - VLESS;
  - Trojan;
  - Shadowsocks.
- Включение/отключение отдельных протоколов через UCI.
- Фильтрация XHTTP.
- Blacklist стран через:

```text
list exclude_country 'RU'
```

- Реальный precheck нод через временный sing-box:
  - отдельный local mixed proxy для каждой проверяемой ноды;
  - HTTP-проверка через сам proxy;
  - batch processing;
  - timeout и connect timeout;
  - контрольный URL;
  - минимальное число рабочих нод;
  - минимальный процент успешных нод.

- Обновление только при изменении итогового рабочего списка по SHA256.
- Запись рабочих нод в Podkop URLTest.
- Проверка итогового конфига через `sing-box check`.
- Автоматический rollback `/etc/config/podkop` при ошибке.
- `procd` service и daemon.
- Отдельный `retry_interval` после неуспешной синхронизации.
- Фильтрация стран по emoji-флагу в имени/fragment proxy-ссылки.
