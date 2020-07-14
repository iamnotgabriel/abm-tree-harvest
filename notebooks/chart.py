import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

plt.style.use("seaborn")

df = pd.DataFrame({
    "Canneti":[.283,.377,.451,.475,.485,.493,.569,.580,.546],
    "Braz_2012":[np.nan,.443,.348,.514,.562,.670,.738,1.042,1.157],
    "Braz_2014":[.438 for i in range(9)],
    "Braz_2015":[np.nan,0.522,.315,.823,1.256,.931,.895,.852,.754],
    "Braz_2017":[.291,.317,.442,.473,.623,.587,.587,.717,.836],
    "Oliveira":[.427,.606,.720,.802,.710,.751,.903,.816,.838],
    "Castro":[.233 for i in range(9)],
    "Borges":[.287,.325,.437,.452,.470,.478,.531,.417,np.nan]}, 
    index= [i for i in range(1, 10)])
# fonts
title = {"fontsize":18, "fontfamily":"Arial", "fontweight":"bold"}
axis = {"fontsize":17, "fontfamily":"Arial"}
# droping unimportant increments
df = df.drop(["Castro", "Braz_2014"], axis = 1)
# filling nan with weighted mean 
df.loc[10] = [4,1,1,1,1,1] # weight by number of tree species studied
mean = {1: (df.loc[1,:"Borges"]*df.loc[10]).sum()/df.loc[10].sum(),
        9: (df.loc[9,:"Borges"]*df.loc[10]).sum()/df.loc[10].sum()}
df2 = df.copy()
df2.loc[1] = df2.loc[1].fillna(mean[1])
df2.loc[9] = df2.loc[9].fillna(mean[9])
# weighted mean
soma = df2.loc[:9,:"Borges"].values * df2.loc[10].values[:]
soma = np.nan_to_num(soma)
mean = soma.sum(axis=1) / df2.loc[10].sum()
df = df.drop(10) # drop weight
# ploting chart
fig, ax = plt.subplots()
df.loc[:,:"Borges"].plot(kind="line", figsize = (12,8), ax=ax)
ax.plot(list(range(1,10)), mean , color="red", linestyle="dashed", label="Média")
# chart style
ax.legend()
plt.plot(kind="line", figsize = (12,8))
plt.xlabel("Classes diamétricas", fontdict=axis)
plt.ylabel("IDA (cm/ano)",fontdict=axis)
plt.title("Incremento diamétrico da literatura\n", fontdict=title)
plt.savefig("incremento_diametrico.png", dpi=300) # save chart
plt.show()
