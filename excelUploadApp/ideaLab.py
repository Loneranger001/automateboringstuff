from recordObj import recordObj

def main():
    r = recordObj('Sheet1', 'Item', 12, 1)
    # rows = []
    rows = [r]
    for r in rows:
        print(r.sheet_name)
        print(r.column_name)

if __name__ == '__main__':
    main()