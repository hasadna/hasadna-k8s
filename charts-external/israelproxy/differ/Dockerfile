FROM python:3.7
RUN pip install requests==2.23.0 ruamel.yaml==0.16.10
RUN mkdir /code
WORKDIR /code
ENV DATA_DIR /data
COPY main.py /code/main.py
CMD ["python", "main.py"]
