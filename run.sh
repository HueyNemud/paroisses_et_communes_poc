jupyter nbconvert --to notebook --execute make_pagebundles_communes.ipynb --inplace \
&& quarto render \
&& hugo \
&& hugo serve -D
