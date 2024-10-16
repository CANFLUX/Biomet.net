import sys
## Progress bar to update status of a run
class progressbar():
    def __init__(self,items,prefix='',size=60,out=sys.stdout):
        self.nItems = items
        self.out = out
        self.i = 0
        self.prefix=prefix
        self.size=size
        self.show(0)

    def show(self,j):
        if self.nItems > 0:
            x = int(self.size*j/self.nItems)
            print(f"{self.prefix}[{u'█'*x}{('.'*(self.size-x))}] {j}/{self.nItems}", end='\r', file=self.out, flush=True)

    def step(self,step_size=1):
        self.i+=step_size
        self.show(self.i)

    def close(self):
        print('\n')

if __name__ == '__main__':
    prefix = 'Test'
    nItems=10
    pb = progressbar(nItems,prefix)
    for i in range(nItems):
        pb.step()
    pb.close()
