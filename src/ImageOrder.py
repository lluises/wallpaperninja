"""
ImageOrder

# Example

io=ImageOrder()
for name in ('patata', 'rice', 'pizza', 'spinach', 'bocata', 'salad'):
    io.append(name)

io.swap('rice', 'salad')
io.insert('pasta', 3)

with open('io.txt', 'w') as fout:
    fout.write(io.serialize())

with open('io.txt', 'r') as fin:
    io = ImageOrder.parse(fin.read())

# Sorting a list
mylist = ['rice, 'bocata', 'patata']
mylist.sort(key=lambda k: io.get(k, 999))
print(my_array)
"""


from typing import List

SEP = ","


class ImageOrder:
    def __init__(self, order=None):
        self.order = order or {} # {"name": position} where position is int
        self.position = self._calc_pos_dict(self.order)

    def swap(self, name1:str, name2:str):
        if name1 not in self.order:
            raise KeyError(f"Not found: {name1}")
        if name2 not in self.order:
            raise KeyError(f"Not found: {name2}")
        pos1 = self.order[name1]
        pos2 = self.order[name2]
        self.order[name1] = pos2
        self.order[name2] = pos1
        self.position[pos1] = name2
        self.position[pos2] = name1

    def append(self, name:str, ignore_duplicates:bool=False):
        if name in self.order:
            if ignore_duplicates:
                return
            raise ValueError("Item already exists")
        self.order[name] = len(self.order)
        self.position[self.order[name]] = name

    def insert(self, name:str, position:int):
        if position > len(self.order):
            position = len(self.order)
        else:
            self.append(name)
            name2 = self.position[position]
            self.swap(name, name2)
        self.order[name] = position

    def remove(self, name:str):
        if name not in self.order:
            raise ValueError("Name not found")
        pos = self.order[name]
        carry = None
        for i in reversed(range(pos, len(self.position))):
            n = self.position.get(i)
            if n is not None:
                self.order[n] = i-1
                self.position[i] = carry
            carry = n
        del self.order[name]
        del self.position[len(self.position)-1]

    def position(self, num:int):
        """
        Returns the name in the given position number or None
        """
        return self.position.get(num)

    def get(self, *args, **kwargs):
        return self.order.get(*args, **kwargs)

    def __getitem__(self, k):
        return order[k]

    def __contains__(self, key:str):
        return (key in self.order)

    def __len__(self):
        return len(self.order)

    def serialize(self) -> str:
        res = []
        for name, pos in self.order.items():
            res.append(f"{name}{SEP}{pos}")
        return '\n'.join(res)

    @staticmethod
    def build_from_list(names:List[str]) -> 'ImageOrder':
        order = {}
        for i, name in enumerate(names):
            order[name] = i
        return ImageOrder(order)

    @staticmethod
    def parse(contents:str) -> 'ImageOrder':
        order = {}
        for line in contents.splitlines():
            parts = line.split(SEP)
            if len(parts) == 2:
                order[parts[0]] = int(parts[1])
        return ImageOrder(order)

    def _calc_pos_dict(self, order:dict):
        return {
            v: k for k, v in order.items()
        }
