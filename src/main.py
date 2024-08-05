
import os
import sys
import hashlib
import http
import hmac
import json

from pathlib import Path
from dotenv import load_dotenv

from github import Github, GithubIntegration
from fastapi import FastAPI, Header, HTTPException, Request, BackgroundTasks
from peewee import SqliteDatabase
from redis import Redis
from rq import Queue
from rq_dashboard_fast import RedisQueueDashboard
import uvicorn
from systemd import journal


# from .db import User

# Get Module version for user agent
current_module = sys.modules[__name__.rsplit('.', 1)[0]]
module_version = getattr(current_module, '__version__', '0.0.0')

# Load environment variables
env_path = Path(__file__).resolve().parent.parent / '.env'
load_dotenv(dotenv_path=env_path)

ghi = GithubIntegration(
    os.environ.get('GITHUB_APP_ID'),
    Path(os.getenv('GITHUB_API_KEY')).read_text())

wh_secret = os.environ.get('WEBHOOK_SECRET').encode('utf-8')

db = SqliteDatabase(os.getenv('SQLITE_DB_PATH'), pragmas={'journal_mode': 'wal'})

queue = Queue(connection=Redis())

# TODO Decide which file of pull request to use for training
# TODO Add job to queue for training

# TODO Spin up RunPod machine
# TODO manage runpod instances (start, shutdown, etc)
# TODO monitor runpod instances
# TODO collect results and update database
# TODO update github with results

def generate_hash_signature( secret: bytes, payload: bytes, digest_method=hashlib.sha1):
    return hmac.new(secret, payload, digest_method).hexdigest()

def connect_repo(ghi: GithubIntegration, owner: str, repo_name: str):
    installation_id = ghi.get_installation(owner, repo_name).id
    access_token = ghi.get_access_token(installation_id).token
    connection = Github(login_or_token=access_token)
    return connection.get_repo(f'{owner}/{repo_name}')

def spin_up_runpod_instance():
    # TODO spin up runpod instance
    pass

def process_payload(payload: dict):
    print(payload)
    if 'repository' in payload:
        owner = payload['repository']['owner']['login']
        repo_name = payload['repository']['name']
        repo = connect_repo(ghi, owner, repo_name)
        if payload.get('issue') and payload['action'] == 'opened':
            issue = repo.get_issue(number=payload['issue']['number'])
            issue.create_comment('Test comment')


def main():
    '''
    Main entry point for the Coordinator.
    Setup Github App and listen for webhook events.
    '''
    journal.send(f'Starting Coordinator {module_version}')

    app = FastAPI()

    dashboard = RedisQueueDashboard(os.getenv('REDIS_URL'), '/rq')
    app.mount('/rq', dashboard)


    @app.post('/webhook', status_code=http.HTTPStatus.ACCEPTED)
    async def webhook(request: Request, x_hub_signature: str = Header(None), background_tasks: BackgroundTasks = BackgroundTasks()):
        # Validate webhook signature
        payload = await request.body()
        signature = generate_hash_signature(wh_secret, payload)
        if x_hub_signature != f'sha1={signature}':
            print('Invalid signature')
            raise HTTPException(status_code=401, detail='Authentication error.')
        
        print('Webhook received')
        
        # Parse webhook payload
        payload = json.loads(payload)
        background_tasks.add_task(process_payload, payload)

        return {}
    
    uvicorn.run(app, host=os.getenv('UVICORN_HOST'), port=int(os.getenv('UVICORN_PORT')), log_level='info')


if __name__ == '__main__':
    main()