# RabbitMQ on Kubernetes #

<img align="right" src="./assets/rabbitmq.png">

**RabbitMQ** — программный брокер сообщений на основе стандарта AMQP — тиражируемое связующее программное обеспечение, ориентированное на обработку сообщений. Создан на основе системы **Open Telecom Platform**, написан на языке **Erlang**, в качестве движка базы данных для хранения сообщений использует **Mnesia**. 

**Robust messaging** для приложений для **connect and scale**. RabbitMQ - это программное обеспечение брокера сообщений с открытым исходным кодом, которое реализует **Advanced Message Queuing Protocol**  (**AMQP**).

Следующие шаги обеспечивают идеальное место для начала **деплоя** и запуска одного из ваших первых приложений в **Kubernetes**. С помощью кластера **Kubernetes** и инструмента **CLI**, называемого **kubectl** и **helm**, вы за несколько шагов запустите **RabbitMQ**.

Вы узнаете, как:

- использовать основы инструментов CLI **kubectl** и **helm**
- установить **RabbitMQ** на **Кубернетес**

> [RabbitMQ](https://www.rabbitmq.com/) - это программное обеспечение брокера сообщений с открытым исходным кодом (иногда называемое **called message-oriented middleware**), которое изначально реализовало **Advanced Message Queuing Protocol** (**AMQP**) и с тех пор было расширено - **plug-in architecture** для поддержки **Streaming Text Oriented Messaging Protocol** (**STOMP**), **Message Queuing Telemetry Transport** (**MQTT**) и других протоколов.

> Серверная программа **RabbitMQ** написана на языке программирования **Erlang** и построена на платформе **Open Telecom Platform** для кластеризации и отработки отказа **failover**.  Клиентские библиотеки для взаимодействия с брокером доступны для всех основных языков программирования. [-- Wikipedia](https://en.wikipedia.org/wiki/RabbitMQ)

**RabbitMQ** – написанный на языке **Erlang** брокер сообщений, позволяющий организовать отказоустойчивый кластер с полной репликацией данных на несколько узлов, где каждый узел может обслуживать запросы на чтение и запись. Имея в **production**-эксплуатации множество кластеров **Kubernetes**, мы поддерживаем большое количество инсталляций **RabbitMQ** и столкнулись с необходимостью миграции данных из одного кластера в другой без простоя.

Мы нашли отличную серию статей, которая сравнивает функциональность **Apache Kafka** и другого (незаслуженно игнорируемого) гиганта среди систем очередей — **RabbitMQ**. 
[December 10, 2017 : RabbitMQ vs Kafka Series Introduction](https://jack-vanlightly.com/blog/2017/12/3/rabbitmq-vs-kafka-series-introduction)