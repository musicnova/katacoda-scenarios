Настройка Django с Postgres, Nginx и Gunicorn в Ubuntu 18.04


Nginx Python PostgreSQL Django Python Frameworks Ubuntu 18.04 Databases


https://www.digitalocean.com/community/tutorials/how-to-set-up-django-with-postgres-nginx-and-gunicorn-on-ubuntu-18-04-ru


https://www.katacoda.com/kennethlove/scenarios/django-tutorial


Введение

Django — это мощная веб-система, помогающая создать приложение или сайт Python с нуля. Django включает упрощенный сервер разработки для локального тестирования кода, однако для серьезных производственных задач требуется более защищенный и мощный веб-сервер.

В этом руководстве мы покажем, как установить и настроить определенные компоненты Ubuntu 18.04 для поддержки и обслуживания приложений Django. Вначале мы создадим базу данных PostgreSQL вместо того, чтобы использовать базу данных по умолчанию SQLite. Мы настроим сервер приложений Gunicorn для взаимодействия с нашими приложениями. Затем мы настроим Nginx для работы в качестве обратного прокси-сервера Gunicorn, что даст нам доступ к функциям безопасности и повышения производительности для обслуживания наших приложений.

Предварительные требования и цели
Для прохождения этого обучающего модуля вам потребуется новый экземпляр сервера Ubuntu 18.04 с базовым брандмауэром и пользователем с привилегиями sudo и без привилегий root. Чтобы узнать, как настроить такой сервер, воспользуйтесь нашим модулем Руководство по начальной настройке сервера.

`
sudo useradd -m -p $(perl -e 'print crypt($ARGV[0], "password")' 'YOUR_PASSWORD') myprojectuser
`{{execute}}
```
```
`
sudo usermod -a -G sudo myprojectuser
`{{execute}}
```
```
`
su - myprojectuser
`{{execute}}

Мы будем устанавливать Django в виртуальной среде. Установка Django в отдельную среду проекта позволит отдельно обрабатывать проекты и их требования.

Когда база данных будет работать, мы выполним установку и настройку сервера приложений Gunicorn. Он послужит интерфейсом нашего приложения и будет обеспечивать преобразование запросов клиентов по протоколу HTTP в вызовы Python, которые наше приложение сможет обрабатывать. Затем мы настроим Nginx в качестве обратного прокси-сервера для Gunicorn, чтобы воспользоваться высокоэффективными механизмами обработки соединений и удобными функциями безопасности.

Давайте приступим.

Установка пакетов из хранилищ Ubuntu
Чтобы начать данную процедуру нужно загрузить и установить все необходимые нам элементы из хранилищ Ubuntu. Для установки дополнительных компонентов мы немного позднее используем диспетчер пакетов Python pip.

Нам нужно обновить локальный индекс пакетов apt, а затем загрузить и установить пакеты. Конкретный состав устанавливаемых пакетов зависит от того, какая версия Python будет использоваться в вашем проекте.

Если вы используете Django с Python 3, введите:
`
sudo apt update`{{execute}}
```
```
`
sudo apt -y install python3-pip python3-dev libpq-dev postgresql postgresql-contrib nginx curl
`{{execute}}
```
```
Версия Django 1.11 — последняя версия Django с поддержкой Python 2. Если вы создаете новый проект, мы настоятельно рекомендуем использовать Python 3. Если вам необходимо использовать Python 2, введите:
```
sudo apt update
```
```
sudo apt install python-pip python-dev libpq-dev postgresql postgresql-contrib nginx curl
```
Эта команда устанавливает pip, файлы разработки Python для последующего построения сервера Gunicorn, СУБД Postgres и необходимые для взаимодействия с ней библиотеки, а также веб-сервер Nginx.

Создание базы данных и пользователя PostgreSQL
Вначале мы создадим базу данных и пользователя базы данных для нашего приложения Django.

По умолчанию Postgres использует для локальных соединений схему аутентификации «peer authentication». Это означает, что если имя пользователя операционной системы совпадает с действительным именем пользователя Postgres, этот пользователь может войти без дополнительной аутентификации.

Во время установки Postgres был создан пользователь операционной системы с именем postgres, соответствующий пользователю postgres базы данных PostgreSQL, имеющему права администратора. Этот пользователь нам потребуется для выполнения административных задач. Мы можем использовать sudo и передать это имя пользователя с опцией -u.

Выполните вход в интерактивный сеанс Postgres, введя следующую команду:
`
sudo -u postgres psql
`{{execute}}
```
```
Вы увидите диалог PostgreSQL, где можно будет задать наши требования.

Вначале создайте базу данных для своего проекта:
`
CREATE DATABASE myproject;
`{{execute}}
```
```
Примечание. Каждое выражение Postgres должно заканчиваться точкой с запятой. Если с вашей командой возникнут проблемы, проверьте это.

Затем создайте пользователя базы данных для нашего проекта. Обязательно выберите безопасный пароль:
`
CREATE USER myprojectuser WITH PASSWORD 'password';
`{{execute}}
```
```
Затем мы изменим несколько параметров подключения для только что созданного нами пользователя. Это ускорит работу базы данных, поскольку теперь при каждом подключении не нужно будет запрашивать и устанавливать корректные значения.

Мы зададим кодировку по умолчанию UTF-8, чего и ожидает Django. Также мы зададим схему изоляции транзакций по умолчанию «read committed», которая будет блокировать чтение со стороны неподтвержденных транзакций. В заключение мы зададим часовой пояс. По умолчанию наши проекты Django настроены на использование времени по Гринвичу (UTC). Все эти рекомендации взяты из проекта Django:
`
ALTER ROLE myprojectuser SET client_encoding TO 'utf8';
`{{execute}}
```
```
`
ALTER ROLE myprojectuser SET default_transaction_isolation TO 'read committed';
`{{execute}}
```
```
`
ALTER ROLE myprojectuser SET timezone TO 'UTC';
`{{execute}}
```
```
Теперь мы предоставим созданному пользователю доступ для администрирования новой базы данных:
`
GRANT ALL PRIVILEGES ON DATABASE myproject TO myprojectuser;
`{{execute}}
```
```
Завершив настройку, закройте диалог PostgreSQL с помощью следующей команды:
`
\q
`{{execute}}
```
```
Теперь настройка Postgres завершена, и Django может подключаться к базе данных и управлять своей информацией в базе данных.

Создание виртуальной среды Python для вашего проекта
Мы создали базу данных, и теперь можем перейти к остальным требованиям нашего проекта. Для удобства управления мы установим наши требования Python в виртуальной среде.

Для этого нам потребуется доступ к команде virtualenv. Для установки мы можем использовать pip.

Если вы используете Python 3, обновите pip и установите пакет с помощью следующей команды:
`
sudo -H pip3 install --upgrade pip
`{{execute}}
```
```
`
sudo -H pip3 install virtualenv
`{{execute}}
```
```
Если вы используете Python 2, обновите pip и установите пакет с помощью следующей команды:
`
sudo -H pip install --upgrade pip
`{{execute}}
```
```
`
sudo -H pip install virtualenv
`{{execute}}
```
```
После установки virtualenv мы можем начать формирование нашего проекта. Создайте каталог для файлов нашего проекта и перейдите в этот каталог:
`
mkdir ~/myprojectdir
`{{execute}}
```
```
`
cd ~/myprojectdir
`{{execute}}
```
```
Создайте в каталоге проекта виртуальную среду Python с помощью следующей команды:
`
virtualenv myprojectenv
`{{execute}}
```
```
Эта команда создаст каталог myprojectenv в каталоге myprojectdir. В этот каталог будут установлены локальная версия Python и локальная версия pip. Мы можем использовать эту команду для установки и настройки изолированной среды Python для нашего проекта.

Прежде чем установить требования Python для нашего проекта, необходимо активировать виртуальную среду. Для этого можно использовать следующую команду:
`
source myprojectenv/bin/activate
`{{execute}}
```
```
Командная строка изменится, показывая, что теперь вы работаете в виртуальной среде Python. Она будет выглядеть примерно следующим образом: (myprojectenv)user@host:~/myprojectdir$.

После запуска виртуальной среды установите Django, Gunicorn и адаптер psycopg2 PostgreSQL с помощью локального экземпляра pip:

Примечание. Если виртуальная среда активна (когда перед командной строкой стоит (myprojectenv)), необходимо использовать pip вместо pip3, даже если вы используете Python 3. Копия инструмента в виртуальной среде всегда имеет имя pip вне зависимости от версии Python.
`
pip install django gunicorn psycopg2-binary
`{{execute}}
```
```
Теперь у вас должно быть установлено все программное обеспечение, необходимое для запуска проекта Django.

Создание и настройка нового проекта Django
Установив компоненты Python, мы можем создать реальные файлы проекта Django.

Создание проекта Django
Поскольку у нас уже есть каталог проекта, мы укажем Django установить файлы в него. В этом каталоге будет создан каталог второго уровня с фактическим кодом (это нормально) и размещен скрипт управления. Здесь мы явно определяем каталог, а не даем Django принимать решения относительно текущего каталога:
`
django-admin.py startproject myproject ~/myprojectdir
`{{execute}}
```
```
Сейчас каталог вашего проекта (в нашем случае ~/myprojectdir) должен содержать следующее:

~/myprojectdir/manage.py: скрипт управления проектами Django.
~/myprojectdir/myproject/: пакет проекта Django. В нем должны содержаться файлы __init__.py, settings.py, urls.py и wsgi.py.
~/myprojectdir/myprojectenv/: виртуальный каталог, которы мы создали до этого.
Изменение настроек проекта
Прежде всего, необходимо изменить настройки созданных файлов проекта. Откройте файл настроек в текстовом редакторе:

nano ~/myprojectdir/myproject/settings.py

Найдите директиву ALLOWED_HOSTS. Она определяет список адресов сервера или доменных имен, которые можно использовать для подключения к экземпляру Django. Любой входящий запрос с заголовком Host, не включенный в этот список, будет вызывать исключение. Django требует, чтобы вы использовали эту настройку, чтобы предотвратить использование определенного класса уязвимости безопасности.

В квадратных скобках перечислите IP-адреса или доменные имена, связанные с вашим сервером Django. Каждый элемент должен быть указан в кавычках, отдельные записи должны быть разделены запятой. Если вы хотите включить в запрос весь домен и любые субдомены, добавьте точку перед началом записи. В следующем фрагменте кода для демонстрации в строках комментариев приведено несколько примеров:

Примечание. Обязательно используйте localhost как одну из опций, поскольку мы будем использовать локальный экземпляр Nginx как прокси-сервер.
`
sed -i "s#ALLOWED_HOSTS = \[\]#ALLOWED_HOSTS = ['*']#g" ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
grep -n 'ALLOWED_HOSTS' ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
```
. . .
# The simplest case: just add the domain name(s) and IP addresses of your Django server
# ALLOWED_HOSTS = [ 'example.com', '203.0.113.5']
# To respond to 'example.com' and any subdomains, start the domain with a dot
# ALLOWED_HOSTS = ['.example.com', '203.0.113.5']
ALLOWED_HOSTS = ['your_server_domain_or_IP', 'second_domain_or_IP', . . ., 'localhost']
```

```
ПРИМЕЧАНИЕ ПЕРЕВОДЧИКА - ПИШИТЕ ПРОСТО ALLOWED_HOSTS = [*] И НЕ УСЛОЖНЯЙТЕ СЕБЕ ЖИЗНЬ
```

Затем найдите раздел. который будет настраивать доступ к базе данных. Он будет начинаться со слова DATABASES. Конфигурация в файле предназначена для базы данных SQLite. Мы уже создали базу данных PostgreSQL для нашего проекта, и поэтому нужно изменить настройки.

Измените настройки, указав параметры базы данных PostgreSQL. Мы укажем Django использовать адаптер psycopg2, который мы установили вместе с pip. Нам нужно указать имя базы данных, имя пользователя базы данных, пароль пользователя базы данных, и указать, что база данных расположена на локальном компьютере. Вы можете оставить для параметра PORT пустую строку:
`
sed -i "s#'ENGINE': 'django.db.*'#'ENGINE': 'django.db.backends.postgresql_psycopg2'#g" ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
sed -i "s#'NAME': os.path.join(BASE_DIR.*#'NAME': 'myproject', 'USER': 'myprojectuser', 'PASSWORD': 'password', 'HOST': 'localhost', 'PORT': ''#g" ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
cat ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
```
. . .

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'myproject',
        'USER': 'myprojectuser',
        'PASSWORD': 'password',
        'HOST': 'localhost',
        'PORT': '',
    }
}

. . .
```
Затем перейдите в конец файла и добавьте параметр, указывающий, где следует разместить статичные файлы. Это необходимо, чтобы Nginx мог обрабатывать запросы для этих элементов. Следующая строка указывает Django, что они помещаются в каталог static в базовом каталоге проекта:
`
sed -i "s#STATIC_URL = '.*#\# STATIC_URL = #g" ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
sed -i "s#STATIC_ROOT = .*#\# STATIC_ROOT = #g" ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
echo -e "\nSTATIC_URL = '/static/'" >> ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
echo -e "\nSTATIC_ROOT = os.path.join(BASE_DIR, 'static/')" >> ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
`
tail -n 20 ~/myprojectdir/myproject/settings.py
`{{execute}}
```
```
```
. . .

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static/')
```
Сохраните файл и закройте его после завершения.

Завершение начальной настройки проекта
Теперь мы можем перенести начальную схему базы данных для нашей базы данных PostgreSQL, используя скрипт управления:
`
~/myprojectdir/manage.py makemigrations
`{{execute}}
```
```
`
~/myprojectdir/manage.py migrate
`{{execute}}
```
```
Создайте административного пользователя проекта с помощью следующей команды:
`
echo ~/myprojectdir/manage.py createsuperuser
`{{execute}}
```
```
`
~/myprojectdir/manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('myprojectuser', 'myemail@', 'adminpass')"
`{{execute}}
```
```
Вам нужно будет выбрать имя пользователя, указать адрес электронной почты, а затем задать и подтвердить пароль.

Мы можем собрать весь статичный контент в заданном каталоге с помощью следующей команды:
`
~/myprojectdir/manage.py collectstatic
`{{execute}}
```
```
Данную операцию нужно будет подтвердить. Статичные файлы будут помещены в каталог static в каталоге вашего проекта.

Если вы следовали указаниям модуля по начальной настройке сервера, ваш сервер должен защищать брандмауэр UFW. Чтобы протестировать сервер разработки, необходимо разрешить доступ к порту, который мы будем использовать.

Создайте исключение для порта 8000 с помощью следующей команды:
`
sudo ufw allow 8000
`{{execute}}
```
```
Теперь вы можете протестировать ваш проект, запустив сервер разработки Django с помощью следующей команды:
`
~/myprojectdir/manage.py runserver 0.0.0.0:8000 >/tmp/myproject.log 2>&1 &
`{{execute}}
```
```
Откройте в браузере доменное имя или IP-адрес вашего сервера с суффиксом :8000:
`
echo 'Click runserver or open https://2886795289-8000-simba08.environments.katacoda.com/'
`{{execute}}
```
http://server_domain_or_IP:8000
```
Вы увидите страницу индекса Django по умолчанию:

Страница индекса Django

Если вы добавите /admin в конце URL в панели адреса, вам будет предложено ввести имя пользователя и пароль администратора, созданные с помощью команды createsuperuser:

Вход в панель администратора Django

После аутентификации вы получите доступ к интерфейсу администрирования Django по умолчанию:

Интерфейс администрирования Django

Завершив изучение, нажмите CTRL+C в окне терминала, чтобы завершить работу сервера разработки.

Тестирование способности Gunicorn обслуживать проект
Перед выходом из виртуальной среды нужно протестировать способность Gunicorn обслуживать приложение. Для этого нам нужно войти в каталог нашего проекта и использовать gunicorn для загрузки модуля WSGI проекта:
`
cd ~/myprojectdir
`{{execute}}
```
```
`
echo gunicorn --bind 0.0.0.0:8000 myproject.wsgi
`{{execute}}
```
```
Gunicorn будет запущен на том же интерфейсе, на котором работал сервер разработки Django. Теперь вы можете вернуться и снова протестировать приложение.

Примечание. В интерфейсе администратора не будут применяться в стили, поскольку Gunicorn неизвестно, как находить требуемый статичный контент CSS.

Мы передали модуль в Gunicorn, указав относительный путь к файлу Django wsgi.py, который представляет собой точку входа в наше приложение. Для этого мы использовали синтаксис модуля Python. В этом файле определена функция application, которая используется для взаимодействия с приложением. Дополнительную информацию о спецификации WSGI можно найти здесь.

После завершения тестирования нажмите CTRL+C в окне терминала, чтобы остановить работу Gunicorn.

Мы завершили настройку нашего приложения Django. Теперь мы можем выйти из виртуальной среды с помощью следующей команды:
`
deactivate
`{{execute}}
```
```
Индикатор виртуальной среды будет убран из командной строки.

Создание файлов сокета и служебных файлов systemd для Gunicorn
Мы убедились, что Gunicorn может взаимодействовать с нашим приложением Django, но теперь нам нужно реализовать более надежный способ запуска и остановки сервера приложений. Для этого мы создадим служебные файлы и файлы сокета systemd.

Сокет Gunicorn создается при загрузке и прослушивает подключения. При подключении systemd автоматически запускает процесс Gunicorn для обработки подключения.

Создайте и откройте файл сокета systemd для Gunicorn с привилегиями sudo:
`
sudo touch /etc/systemd/system/gunicorn.socket
`{{execute}}
```
```
В этом файле мы создадим раздел [Unit] для описания сокета, раздел [Socket] для определения расположения сокета и раздел [Install], чтобы обеспечить установку сокета в нужное время:
`
sudo bash -c "cat >> /etc/systemd/system/gunicorn.socket " << EOF
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
EOF
`{{execute}}
```
```
`
sudo cat /etc/systemd/system/gunicorn.socket
`{{execute}}
```
```

Сохраните файл и закройте его после завершения.

Теперь создайте и откройте служебный файл systemd для Gunicorn в текстовом редакторе с привилегиями sudo. Имя файла службы должно соответствовать имени файла сокета за исключением расширения:
`
sudo touch /etc/systemd/system/gunicorn.service
`{{execute}}
```
```

Начните с раздела [Unit], предназначенного для указания метаданных и зависимостей. Здесь мы разместим описание службы и предпишем системе инициализации запускать ее только после достижения сетевой цели: Поскольку наша служба использует сокет из файла сокета, нам потребуется директива Requires, чтобы задать это отношение:
`
sudo bash -c "cat >> /etc/systemd/system/gunicorn.service " << EOF
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target
EOF
`{{execute}}
```
```
`
sudo cat /etc/systemd/system/gunicorn.service
`{{execute}}
```
```

Теперь откроем раздел [Service]. Здесь указываются пользователь и группа, от имени которых мы хотим запустить данный процесс. Мы сделаем владельцем процесса учетную запись обычного пользователя, поскольку этот пользователь является владельцем всех соответствующих файлов. Групповым владельцем мы сделаем группу www-data, чтобы Nginx мог легко взаимодействовать с Gunicorn.

Затем мы составим карту рабочего каталога и зададим команду для запуска службы. В данном случае мы укажем полный путь к исполняемому файлу Gunicorn, установленному в нашей виртуальной среде. Мы привяжем процесс к сокету Unix, созданному в каталоге /run, чтобы процесс мог взаимодействовать с Nginx. Мы будем регистрировать все данные на стандартном выводе, чтобы процесс journald мог собирать журналы Gunicorn. Также здесь можно указать любые необязательные настройки Gunicorn. Например, в данном случае мы задали 3 рабочих процесса:
```
```
`
sudo bash -c "cat >> /etc/systemd/system/gunicorn.service " << EOF
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=sammy
Group=www-data
WorkingDirectory=/home/sammy/myprojectdir
ExecStart=/home/sammy/myprojectdir/myprojectenv/bin/gunicorn \\
          --access-logfile - \\
          --workers 3 \\
          --bind unix:/run/gunicorn.sock \\
          myproject.wsgi:application
EOF
`{{execute}}
```
```
`
sudo cat /etc/systemd/system/gunicorn.service
`{{execute}}
```
```

Наконец, добавим раздел [Install]. Это покажет systemd, куда привязывать эту службу, если мы активируем ее запуск при загрузке. Нам нужно, чтобы эта служба запускалась во время работы обычной многопользовательской системы:
```
```
`
sudo bash -c "cat >> /etc/systemd/system/gunicorn.service " << EOF
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=sammy
Group=www-data
WorkingDirectory=/home/sammy/myprojectdir
ExecStart=/home/sammy/myprojectdir/myprojectenv/bin/gunicorn \\
          --access-logfile - \\
          --workers 3 \\
          --bind unix:/run/gunicorn.sock \\
          myproject.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
`{{execute}}
```
```
Теперь служебный файл systemd готов. Сохраните и закройте его.

Теперь мы можем запустить и активировать сокет Gunicorn. Файл сокета /run/gunicorn.sock будет создан сейчас и будет создаваться при загрузке. При подключении к этому сокету systemd автоматически запустит gunicorn.service для его обработки:
`
sudo systemctl start gunicorn.socket
`{{execute}}
```
```
`
sudo systemctl enable gunicorn.socket
`{{execute}}
```
```
`
sudo cat /etc/systemd/system/gunicorn.service
`{{execute}}
```
```

Успешность операции можно подтвердить, проверив файл сокета.

Проверка файла сокета Gunicorn
Проверьте состояние процесса, чтобы узнать, удалось ли его запустить:
`
sudo systemctl status gunicorn.socket
`{{execute}}
```
```
Затем проверьте наличие файла gunicorn.sock в каталоге /run:
`
file /run/gunicorn.sock
`{{execute}}
```
Output
/run/gunicorn.sock: socket
```


Если команда systemctl status указывает на ошибку, или если в каталоге отсутствует файл gunicorn.sock, это означает, что сокет Gunicorn не удалось создать. Проверьте журналы сокета Gunicorn с помощью следующей команды:
`
sudo journalctl -u gunicorn.socket
`{{execute}}
```
```
Еще раз проверьте файл /etc/systemd/system/gunicorn.socket и устраните любые обнаруженные проблемы, прежде чем продолжить.

Тестирование активации сокета
Если вы запустили только gunicorn.socket, служба gunicorn.service не будет активна в связи с отсутствием подключений к совету. Для проверки можно ввести следующую команду:
`
sudo systemctl status gunicorn
`{{execute}}
```
Output
● gunicorn.service - gunicorn daemon
   Loaded: loaded (/etc/systemd/system/gunicorn.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
Чтобы протестировать механизм активации сокета, установим соединение с сокетом через curl с помощью следующей команды:
```
`
curl --unix-socket /run/gunicorn.sock localhost
`{{execute}}
```
```
Выводимые данные приложения должны отобразиться в терминале в формате HTML. Это показывает, что Gunicorn запущен и может обслуживать ваше приложение Django. Вы можете убедиться, что служба Gunicorn работает, с помощью следующей команды:
`
sudo systemctl status gunicorn
`{{execute}}
```
Output
● gunicorn.service - gunicorn daemon
   Loaded: loaded (/etc/systemd/system/gunicorn.service; disabled; vendor preset: enabled)
   Active: active (running) since Mon 2018-07-09 20:00:40 UTC; 4s ago
 Main PID: 1157 (gunicorn)
    Tasks: 4 (limit: 1153)
   CGroup: /system.slice/gunicorn.service
           ├─1157 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application
           ├─1178 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application
           ├─1180 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application
           └─1181 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application

Jul 09 20:00:40 django1 systemd[1]: Started gunicorn daemon.
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1157] [INFO] Starting gunicorn 19.9.0
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1157] [INFO] Listening at: unix:/run/gunicorn.sock (1157)
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1157] [INFO] Using worker: sync
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1178] [INFO] Booting worker with pid: 1178
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1180] [INFO] Booting worker with pid: 1180
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1181] [INFO] Booting worker with pid: 1181
Jul 09 20:00:41 django1 gunicorn[1157]:  - - [09/Jul/2018:20:00:41 +0000] "GET / HTTP/1.1" 200 16348 "-" "curl/7.58.0"
`{{execute}}
```

Если результат вывода curl или systemctl status указывают на наличие проблемы, поищите в журналах более подробные данные:
`
sudo journalctl -u gunicorn
`{{execute}}
```
```
Проверьте файл /etc/systemd/system/gunicorn.service на наличие проблем. Если вы внесли изменения в файл /etc/systemd/system/gunicorn.service, перезагрузите демона, чтобы заново считать определение службы, и перезапустите процесс Gunicorn с помощью следующей команды:
`
sudo systemctl daemon-reload
`{{execute}}
`
sudo systemctl restart gunicorn
·{{execute}}
```
```
Обязательно устраните вышеперечисленные проблемы, прежде чем продолжить.

Настройка Nginx как прокси для Gunicorn
Мы настроили Gunicorn, и теперь нам нужно настроить Nginx для передачи трафика в процесс.

Для начала нужно создать и открыть новый серверный блок в каталоге Nginx sites-available:
`
sudo nano /etc/nginx/sites-available/myproject
`{{execute}}
```
```
Откройте внутри него новый серверный блок. Вначале мы укажем, что этот блок должен прослушивать обычный порт 80, и что он должен отвечать на доменное имя или IP-адрес нашего сервера:
`
sudo bash -c "cat >> /etc/nginx/sites-available/myproject " << EOF
server {
    listen 80;
    server_name server_domain_or_IP;
}
EOF
`{{execute}}
```
```
`
sudo cat /etc/nginx/sites-available/myproject
`{{execute}}
```
```
Затем мы укажем Nginx игнорировать любые проблемы при поиске favicon. Также мы укажем, где можно найти статичные ресурсы, собранные нами в каталоге ~/myprojectdir/static. Все эти строки имеют стандартный префикс URI «/static», так что мы можем создать блок location для соответствия этим запросам:
`
sudo bash -c "cat >> /etc/nginx/sites-available/myproject " << EOF
server {
    listen 80;
    server_name server_domain_or_IP;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /home/sammy/myprojectdir;
    }
}
EOF
`{{execute}}
```
```
`
sudo cat /etc/nginx/sites-available/myproject
`{{execute}}
```
```
В заключение мы создадим блок location / {} для соответствия всем другим запросам. В этот блок мы включим стандартный файл proxy_params, входящий в комплект установки Nginx, и тогда трафик будет передаваться напрямую на сокет Gunicorn:
`
sudo bash -c "cat >> /etc/nginx/sites-available/myproject " << EOF
server {
    listen 80;
    server_name server_domain_or_IP;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /home/sammy/myprojectdir;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF
`{{execute}}
```
```
`
sudo cat /etc/nginx/sites-available/myproject
`{{execute}}
```
```
Сохраните файл и закройте его после завершения. Теперь мы можем активировать файл, привязав его к каталогу sites-enabled:
`
sudo ln -s /etc/nginx/sites-available/myproject /etc/nginx/sites-enabled
`{{execute}}
```
```
Протестируйте конфигурацию Nginx на ошибки синтаксиса:
`
sudo nginx -t
`{{execute}}
```
```
Если ошибок не будет найдено, перезапустите Nginx с помощью следующей команды:
`
sudo systemctl restart nginx
`{{execute}}
```
```
Нам нужна возможность открыть брандмауэр для обычного трафика через порт 80. Поскольку нам больше не потребуется доступ к серверу разработки, мы можем удалить правило и открыть порт 8000:
`
sudo ufw delete allow 8000
`{{execute}}
```
```
`
sudo ufw allow 'Nginx Full'
`{{execute}}
```
```
Теперь у вас должна быть возможность перейти к домену или IP-адресу вашего сервера для просмотра вашего приложения.

Примечание. После настройки Nginx необходимо защитить трафик на сервер с помощью SSL/TLS. Это важно, поскольку в противном случае вся информация, включая пароли, будет отправляться через сеть в простом текстовом формате.

Если у вас имеется доменное имя, проще всего будет использовать Let’s Encrypt для получения сертификата SSL для защиты вашего трафика. Следуйте указаниям этого руководства, чтобы настроить Let’s Encrypt с Nginx в Ubuntu 18.04. Следуйте процедуре, используя серверный блок Nginx, созданный нами в этом обучающем модуле.

Если у вас нет доменного имени, вы можете защитить свой сайт для тестирования и обучения с помощью сертификата SSL с собственной подписью. Следуйте процедуре, используя серверный блок Nginx, созданный нами в этом обучающем модуле.

Диагностика и устранение неисправностей Nginx и Gunicorn
Если на последнем шаге не будет показано ваше приложение, вам нужно будет провести диагностику и устранение неисправностей установки.

Nginx показывает страницу по умолчанию, а не приложение Django
Если Nginx показывает страницу по умолчанию, а не выводит ваше приложение через прокси, это обычно означает, что вам нужно изменить параметр server_name в файле /etc/nginx/sites-available/myproject, чтобы он указывал на IP-адрес или доменное имя вашего сервера.

Nginx использует server_name, чтобы определять, какой серверный блок использовать для ответа на запросы. Если вы увидите страницу Nginx по умолчанию, это будет означать, что Nginx не может найти явное соответствие запросу в серверном блоке и выводит блок по умолчанию, заданный в /etc/nginx/sites-available/default.

Параметр server_name в серверном блоке вашего проекта должен быть более конкретным, чем содержащийся в серверном блоке, выбираемом по умолчанию.

Nginx выводит ошибку 502 Bad Gateway вместо приложения Django
Ошибка 502 означает, что Nginx не может выступать в качестве прокси для запроса. Ошибка 502 может сигнализировать о разнообразных проблемах конфигурации, поэтому для диагностики и устранения неисправности потребуется больше информации.

В первую очередь эту информацию следует искать в журналах ошибок Nginx. Обычно это указывает, какие условия вызвали проблемы во время прокси-обработки. Изучите журналы ошибок Nginx с помощью следующей команды:
`
sudo tail -F /var/log/nginx/error.log
`{{execute}}
```
```
Теперь выполните в браузере еще один запрос, чтобы получить свежее сообщение об ошибке (попробуйте обновить страницу). В журнал будет записано свежее сообщение об ошибке. Если вы изучите его, это поможет идентифицировать проблему.

Возможно вы увидите сообщение следующего вида:

connect() to unix:/run/gunicorn.sock failed (2: No such file or directory)

Это означает, что Nginx не удалось найти файл gunicorn.sock в указанном месте. Вы должны сравнить расположение proxy_pass, определенное в файле etc/nginx/sites-available/myproject, с фактическим расположением файла gunicorn.sock, сгенерированным блоком systemd gunicorn.socket.

Если вы не можете найти файл gunicorn.sock в каталоге /run, это означает, что файл сокета systemd не смог его создать. Вернитесь к разделу проверки файла сокета Gunicorn и выполните процедуру диагностики и устранения неисправностей Gunicorn.

connect() to unix:/run/gunicorn.sock failed (13: Permission denied)

Это означает, что Nginx не удалось подключиться к сокету Gunicorn из-за проблем с правами доступа. Это может произойти, если процедуру выполнять с привилегиями root, а не с привилегиями sudo. Хотя systemd может создать файл сокета Gunicorn, Nginx не может получить к нему доступ.

Это может произойти из-за ограничения прав доступа в любом месте между корневым каталогом (/) и файлом gunicorn.sock. Чтобы увидеть права доступа и владельцев файла сокета и всех его родительских каталогов, нужно ввести абсолютный путь файла сокета как параметр команды namei:
`
namei -l /run/gunicorn.sock
`{{execute}}
```
Output
f: /run/gunicorn.sock
drwxr-xr-x root root /
drwxr-xr-x root root run
srw-rw-rw- root root gunicorn.sock
```
Команда выведет права доступа всех компонентов каталога. Изучив права доступа (первый столбец), владельца (второй столбец) и группового владельца (третий столбец), мы можем определить, какой тип доступа разрешен для файла сокета.

В приведенном выше примере для файла сокета и каждого из каталогов пути к файлу сокета установлены всеобщие права доступа на чтение и исполнение (запись в столбце разрешений каталогов заканчивается на r-x, а не на ---). Процесс Nginx должен успешно получить доступ к сокету.

Если для любого из каталогов, ведущих к сокету, отсутствуют глобальные разрешения на чтение и исполнение, Nginx не сможет получить доступ к сокету без включения таких разрешений или без передачи группового владения группе, в которую входит Nginx.

Django выводит ошибку: «could not connect to server: Connection refused»
При попытке доступа к частям приложения через браузер Django может вывести сообщение следующего вида:
```
OperationalError at /admin/login/
could not connect to server: Connection refused
    Is the server running on host "localhost" (127.0.0.1) and accepting
    TCP/IP connections on port 5432?
```
Это означает, что Django не может подключиться к базе данных Postgres. Убедиться в нормальной работе экземпляра Postgres с помощью следующей команды:

`
sudo systemctl status postgresql
`{{execute}}
```
```
Если он работает некорректно, вы можете запустить его и включить автоматический запуск при загрузке (если эта настройка еще не задана) с помощью следующей команды:
`
sudo systemctl start postgresql
`{{execute}}
```
```
`
sudo systemctl enable postgresql
`{{execute}}
```
```
Если проблемы не исчезнут, проверьте правильность настроек базы данных, заданных в файле ~/myprojectdir/myproject/settings.py.

Дополнительная диагностика и устранение неисправностей
В случае обнаружения дополнительных проблем журналы могут помочь в поиске первопричин. Проверяйте их по очереди и ищите сообщения, указывающие на проблемные места.

Следующие журналы могут быть полезными:

Проверьте журналы процессов Nginx с помощью команды: 
`
sudo journalctl -u nginx
`{{execute}}
```
```
Проверьте журналы доступа Nginx с помощью команды: 
`
sudo less /var/log/nginx/access.log
`{{execute}}
```
```
Проверьте журналы ошибок Nginx с помощью команды: 
`
sudo less /var/log/nginx/error.log
`{{execute}}
```
```
Проверьте журналы приложения Gunicorn с помощью команды: 
`
sudo journalctl -u gunicorn
`{{execute}}
```
```
Проверьте журналы сокета Gunicorn с помощью команды:
`
sudo journalctl -u gunicorn.socket
`{{execute}}
```
```
При обновлении конфигурации или приложения вам может понадобиться перезапустить процессы для адаптации к изменениям.

Если вы обновите свое приложение Django, вы можете перезапустить процесс Gunicorn для адаптации к изменениям с помощью следующей команды:
`
sudo systemctl restart gunicorn
`{{execute}}
```
```
Если вы измените файл сокета или служебные файлы Gunicorn, перезагрузите демона и перезапустите процесс с помощью следующей команды:
`
sudo systemctl daemon-reload
`{{execute}}
```
```
`
sudo systemctl restart gunicorn.socket gunicorn.service
`{{execute}}
```
```
Если вы измените конфигурацию серверного блока Nginx, протестируйте конфигурацию и Nginx с помощью следующей команды:
`
sudo nginx -t && sudo systemctl restart nginx
`{{execute}}
```
```
Эти команды помогают адаптироваться к изменениям в случае изменения конфигурации.

Заключение
В этом руководстве мы создали и настроили проект Django в его собственной виртуальной среде. Мы настроили Gunicorn для трансляции запросов клиентов, чтобы Django мог их обрабатывать. Затем мы настроили Nginx в качестве обратного прокси-сервера для обработки клиентских соединений и вывода проектов, соответствующих запросам клиентов.

Django упрощает создание проектов и приложений, предоставляя множество стандартных элементов и позволяя сосредоточиться на уникальных. Используя описанную в этой статье процедуру, вы сможете легко обслуживать создаваемые приложения на одном сервере.


