from recordObj import recordObj
from datetime import datetime

def main():
    if not retCode(2):
        print('failed')
    else:
        print('Success')


def retCode(val):
    if val == 1:
        return False
    else:
        return True
if __name__ == '__main__':
    main()
    print(datetime.now().strftime('%Y%m%d%H%M%S'))