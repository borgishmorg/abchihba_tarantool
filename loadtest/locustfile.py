import random
from locust import LoadTestShape, FastHttpUser, task, constant_throughput

LINKS = (
    'http://vk.com',
    'http://ya.ru',
    'http://mail.ru',
    'http://google.com'
)
stage = 1


class QuickstartUser(FastHttpUser):

    wait_time = constant_throughput(1000)

    def __init__(self, environment):
        super().__init__(environment)
        self.links = list()

    @task
    def test(self):
        global stage
        global fetched_links
        if stage == 1:
            self.generate_link()
        elif stage == 2:
            if not self.links:
                self.generate_link()
            link, shorten_link = random.choice(self.links)
            self.client.get(
                shorten_link,
                name='/:uuid',
                allow_redirects=False
            )

    def generate_link(self):
        link = random.choice(LINKS)
        shorten_link = self.client.post("/set", json={'link': link}).text
        self.links.append((link, f'/{shorten_link.split("/")[-1]}'))


class MyCustomShape(LoadTestShape):
    user_count = (1, 50)
    stage_one_time_limit = 20
    time_limit = 60

    def tick(self):
        global stage
        run_time = self.get_run_time()

        if run_time < self.time_limit:
            if stage == 1 and run_time > MyCustomShape.stage_one_time_limit:
                stage = 2
            return (MyCustomShape.user_count[stage-1], 10)

        return None
