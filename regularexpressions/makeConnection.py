import cx_Oracle

CONN_INFO = {
    'host': '',
    'port': 1521,
    'user': 'alaskar_db',
    'password': 'xx',
    'service':'xx'
}

CONN_STR = '{user}/{password}@{host}:{port}/{service}'.format(**CONN_INFO)

class DB:
    def __init__(self):
        self.conn = cx_Oracle.connect(CONN_STR)

    def query(self, query, params = None):
        cursor = self.conn.cursor()
