import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def lambda_handler(event, context):
    print(event)

    email = None
    status = None

    for record in event['Records']:
        if record['eventName'] in ['INSERT', 'MODIFY']:
            new_image = record['dynamodb']['NewImage']
            email = new_image['email']['S']
            status = new_image['status']['S']
            

            print(f"Email: {email}, Status: {status}")

    smtp_server = "smtp.gmail.com" 
    smtp_port = 587
    smtp_user = "6soatgrupo74@gmail.com"
    smtp_password = "jwtc wtzm lqku htxa" 


    remetente = smtp_user
    destinatario = event.get("to", email)
    assunto = event.get("subject", f"Alteracao de status do processamento do seu video : {status}")
    mensagem = event.get("message", f"Ola, gostariamos de informar o status de processamento do seu video: {status}")

    email = MIMEMultipart()
    email["From"] = remetente
    email["To"] = destinatario
    email["Subject"] = assunto
    email.attach(MIMEText(mensagem, "plain"))

    try:

        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_password) 
            server.sendmail(remetente, destinatario, email.as_string()) 

        return {
            "statusCode": 200,
            "body": "E-mail enviado com sucesso"
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": f"Falha ao enviar o e-mail: {str(e)}"
        }