# CustomKVO
# 手动实现KVO
# 源自http://tech.glowing.com/cn/implement-kvo/
### 实现步骤
#### 1.检查对象的类有没有相应的 setter 方法。如果没有抛出异常；
#### 2.检查对象 isa 指向的类是不是一个 KVO 类。如果不是，新建一个继承原来类的子类，并把 isa 指向这个新建的子类；
#### 3.检查对象的 KVO 类重写过没有这个 setter 方法。如果没有，添加重写的 setter 方法；
#### 4.添加这个观察者
