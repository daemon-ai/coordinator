
from pathlib import Path
import os
from dotenv import load_dotenv

from github import Github
from github_bot_api import GithubApp, Webhook, Event
from github_bot_api.flask import create_flask_app

env_path = Path(__file__).resolve().parent.parent / '.env'
load_dotenv(dotenv_path=env_path)


def main():
    
    app = GithubApp(
        user_agent='daemon-coordinator/0.1.0',
        app_id=os.getenv("GITHUB_APP_ID"),
        private_key=Path(os.getenv("GITHUB_API_KEY")).read_text(),
    )

    webhook = Webhook(secret=os.getenv('WEBHOOK_SECRET'))

    def on_any_event(event: Event) -> bool:
        print(event)
        return True
    webhook.listen('*', on_any_event)


    @webhook.listen('label')
    def on_label(event: Event) -> bool:
        print('label', event)
        return True

    @webhook.listen('pull_request')
    def on_pull_request(event: Event) -> bool:
        client: Github = app.installation_client(event.payload['installation']['id'])
        repo = client.get_repo(event['repository']['full_name'])
        pr = repo.get_pull(event['pull_request']['number'])
        pr.create_issue_comment('Coordinator test')
        return True

    flask_app = create_flask_app(__name__, webhook, path = '/webhook')
    flask_app.run(host=os.getenv('FLASK_RUN_HOST'), port=os.getenv('FLASK_RUN_PORT'))


if __name__ == "__main__":
    main()