Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


function Get-DnsActive{
    $interfaceUP = Get-NetAdapter | Where-Object{$_.Status -eq 'Up'} | Select-Object -First 1
     
    if($interfaceUP){
        $dns = (Get-DnsClientServerAddress -InterfaceAlias $interfaceUP.Name -AddressFamily IPv4).ServerAddresses
        Write-Host "Tipo de $dns : $($dns.GetType())"
        if($dns){
            return $dns[0]
        }else{
            return "Nenhum dns encontrado"
        }
    }else{
        return "Rede nao esta ativa"
    }
}


$IP_DNS = "8.8.8.8"
Write-Host $IP_DNS


# ------------------------------------------------- Daqui pra baixo é funcoes -------------------------------------------------

# Função para testar latência de busca (ping)
function Test-Latency {
    Write-Host $DNS
    $pingResult = Test-Connection -ComputerName $IP_DNS -Count 4 -ErrorAction SilentlyContinue
    if ($pingResult) {
        foreach ($i in $pingResult.Latency) {
           $latency += $i
        }
        return $latency = $latency / 4
        Write-Host $latency
    } else {
        "Falha ao conectar-se ao DNS $IP_DNS."
    }
}


# Função para obter o IP público
function Get-PublicIP {
       Write-Host "entrouuu"
    try {
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org"
        return $publicIP 
    } catch {
        return "Erro ao obter o seu ip publico."
    }
}

# Função para listar IPs e portas utilizadas pela máquina local
function Get-LocalConnections {
    $connections = Get-NetTCPConnection | Where-Object { $_.State -eq 'Established' }
    $output = "{0,-20} {1,-10} {2,-20} {3,-10}" -f "Conexao local", "Porta", "IP Remoto", "Porta"
    $output += [Environment]::NewLine
    
    # Loop para adicionar as informações de cada conexão
    foreach ($conn in $connections) {
        $output += "{0,-20}     {1,-10} {2,-20}     {3,-10}" -f $conn.LocalAddress, $conn.LocalPort, $conn.RemoteAddress, $conn.RemotePort
        $output += [Environment]::NewLine
    }
    
    # Exibe a saída
    $output
}

# Função para identificar Conexões suspeitas
function Check-SuspiciousConnections {
    $suspiciousIPs = @("192.168.1.100", "127.0.0.1", "0.0.0.0", "192.16.48.200", "52.179.73.39", "201.0.219.139", "81.19.104.212", "8.8.8.8") 
    $connections = Get-NetTCPConnection | Where-Object { $_.State -eq 'Established' }

    foreach ($conn in $connections) {
        if ($suspiciousIPs -contains $conn.RemoteAddress) {
            # Criar o diálogo de alerta para a conexão suspeita
            $dialogMessage = "Conexao suspeita detectada: `n" + 
                             "IP Remoto: $($conn.RemoteAddress), Porta: $($conn.RemotePort)"
            $dialogTitle = "Conexão Suspeita Detectada"

            # Exibir a caixa de mensagem com uma opção para fechar a conexão
            $result = [System.Windows.Forms.MessageBox]::Show($dialogMessage, $dialogTitle, 
                                                               [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                                                               [System.Windows.Forms.MessageBoxIcon]::Warning)

            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                # Tentar obter o PID associado à conexão suspeita
                $connectionToClose = Get-NetTCPConnection | Where-Object { $_.RemoteAddress -eq $conn.RemoteAddress -and $_.RemotePort -eq $conn.RemotePort }

                if ($connectionToClose) {
                    try {
                        # Obter o PID associado a essa conexão com nome de variável diferente
                        $processId = (Get-NetTCPConnection -RemoteAddress $conn.RemoteAddress -RemotePort $conn.RemotePort).OwningProcess

                        if ($processId) {
                            # Finalizar o processo que está mantendo a conexão
                            Stop-Process -Id $processId -Force
                            [System.Windows.Forms.MessageBox]::Show("Conexão com $($conn.RemoteAddress):$($conn.RemotePort) foi fechada com sucesso.", "Conexão Fechada")
                        }
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Erro ao tentar fechar a conexão. Detalhes do erro: $_", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    }
                }
            }
        }
    }
}

# Função para Pegar o DNS


function Get-NameAdapter{
    $interfaceUPName = (Get-NetAdapter | Where-Object{$_.Status -eq 'Up'} | Select-Object -First 1).Name
    Write-Host $interfaceUPName
    return $interfaceUPName
}

function Get-ActualIp{
    # $ipActual =(Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.PrefixLength -eq 24} | Select-Object -First 1).IPAddress
    $ipActual =(Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" } | Select-Object -First 1).IPAddress
    Write-Host "ip atual" + $ipActual
    if($ipActual){
        return $ipActual
    }else{
        return "erro ao obter o ip atual"
    }
}

# Função para mostrar o DNS atual
function Set-DnsServer {
    param (
        [string]$dns
    )
    
    try {
        $interfaceUP = Get-NameAdapter
         Write-Host $interfaceUP
        if ($interfaceUP) {
            Set-DnsClientServerAddress -InterfaceAlias $interfaceUP -ServerAddresses $dns
            [System.Windows.Forms.MessageBox]::Show("DNS alterado com sucesso!", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $dnsLabel.Text = "DNS atual:" + (Get-DnsActive)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Nenhuma interface de rede ativa encontrada.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erro ao alterar o DNS. Detalhes: $_", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}


function Reset-Dns{
    try {
        $interfaceUP = Get-NameAdapter
        if ($interfaceUP) {
            # Resetar o DNS para o padrão automático
            Set-DnsClientServerAddress -InterfaceAlias $interfaceUP -ResetServerAddresses
            [System.Windows.Forms.MessageBox]::Show("DNS resetado para automatico (DHCP).", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $dnsLabel.Text = "DNS atual:" + (Get-DnsActive)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Nenhuma interface de rede ativa encontrada.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erro ao resetar o DNS. Detalhes: $_", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}
# ------------------------------------------------- Daqui pra baixo é so botoes e interface -------------------------------------------------


# Configuração da janela principal
$form = New-Object Windows.Forms.Form
$form.Text = "Monitor de Rede"
$form.Size = New-Object Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"

# Configuração do campo de exibição
$outputBox = New-Object Windows.Forms.TextBox
$outputBox.Size = New-Object Drawing.Size(770, 210)
$outputBox.Location = New-Object Drawing.Point(10,0)  
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.BackColor = [System.Drawing.Color]::LightSlateGray 
$form.Controls.Add($outputBox)

# Criar o Panel para a linha horizontal
$linePanel = New-Object Windows.Forms.Panel
$linePanel.Size = New-Object Drawing.Size(780, 2)   # Define a altura da linha
$linePanel.Location = New-Object Drawing.Point(0,220)  # Coloca abaixo do TextBox
$linePanel.BackColor = [System.Drawing.Color]::Black  # Define a cor da linha
$form.Controls.Add($linePanel)

# Criar o Panel para a linha horizontal
$linePanel2 = New-Object Windows.Forms.Panel 
$linePanel2.Size = New-Object Drawing.Size(780, 2)   # Define a altura da linha
$linePanel2.Location = New-Object Drawing.Point(0,250)  # Coloca abaixo do TextBox
$linePanel2.BackColor = [System.Drawing.Color]::Black  # Define a cor da linha
$form.Controls.Add($linePanel2)



# # Impede redimensionamento e movimento da janela
# $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
# $form.MaximizeBox = $false  # Desabilita o botão de maximizar
# $form.MinimizeBox = $false  # Desabilita o botão de minimizar

# # Isso impede que a janela seja movida
# $form.ShowInTaskbar = $false  # A janela não aparece na barra de tarefas
# $form.TopMost = $true  # Faz a janela sempre ficar em cima das outras

#Responsividade
# $form.Add_Resize({
#     $minWidth = 200
#     $minHeight = 100
#     $outputBox.Width = [math]::Max($form.ClientSize.Width - 20, $minWidth)
#     $outputBox.Height = [math]::Max($form.ClientSize.Height - 160, $minHeight)
# })

# Botão para exibir a latência 10,210
$latencyButton = New-Object Windows.Forms.Button
$latencyButton.Text = "Testar Latencia"
$latencyButton.Location = New-Object Drawing.Point(10, 270)
$latencyButton.Size = New-Object Drawing.Size(180, 30)
$latencyButton.Add_Click({
    $outputBox.Text = "Analise de Latencia" + [Environment]::NewLine
    $outputBox.Text += "Latencia media para ${IP_DNS}: " + (Test-Latency) + " ms`n" 
})
$form.Controls.Add($latencyButton)

# Botão para exibir Conexões locais
$localConnectionsButton = New-Object Windows.Forms.Button
$localConnectionsButton.Text = "Ver Conexoes Locais"
$localConnectionsButton.Location = New-Object Drawing.Point(200, 270)
$localConnectionsButton.Size = New-Object Drawing.Size(180, 30)
$localConnectionsButton.Add_Click({
    $outputBox.Text = "Conexoes Locais" + [Environment]::NewLine
    $outputBox.Text += (Get-LocalConnections)
})
$form.Controls.Add($localConnectionsButton)

# Botão para exibir IP público
$publicIPButton = New-Object Windows.Forms.Button
$publicIPButton.Text = "Revelar IP Publico"
$publicIPButton.Location = New-Object Drawing.Point(390, 270)
$publicIPButton.Size = New-Object Drawing.Size(180, 30)

$form.Controls.Add($publicIPButton)

# Botão para verificar Conexões suspeitas
$suspiciousConnectionsButton = New-Object Windows.Forms.Button
$suspiciousConnectionsButton.Text = "Ver Conexoes Suspeitas"
$suspiciousConnectionsButton.Location = New-Object Drawing.Point(580, 270)
$suspiciousConnectionsButton.Size = New-Object Drawing.Size(180, 30)
$suspiciousConnectionsButton.Add_Click({
    $outputBox.Text = "Conexões Suspeitas`n"
    Check-SuspiciousConnections
})
$form.Controls.Add($suspiciousConnectionsButton)


# Botão para limpar o campo de exibição
$clearButton = New-Object Windows.Forms.Button
$clearButton.Text = "Limpar"
$clearButton.Location = New-Object Drawing.Point(10, 360)
$clearButton.Size = New-Object Drawing.Size(750, 30)
$clearButton.Add_Click({
    $outputBox.Clear()
})
$form.Controls.Add($clearButton)

$changeDnsButton = New-Object Windows.Forms.Button
$changeDnsButton.Text = "Configurar DNS"
$changeDnsButton.Location = New-Object Drawing.Point(10, 320)
$changeDnsButton.Size = New-Object Drawing.Size(750, 30)

$form.Controls.Add($changeDnsButton)

$changeDnsButton.Add_Click({
    Show-DnsInputDialog
})

function Show-DnsInputDialog {
    $inputForm = New-Object Windows.Forms.Form
    $inputForm.Text = "Alterar DNS"
    $inputForm.Size = New-Object Drawing.Size(400, 200)  # Aumentando o tamanho para caber os dois botões
    $inputForm.StartPosition = "CenterScreen"

    # Label para o campo de entrada
    $label = New-Object Windows.Forms.Label
    $label.Text = "Digite o novo DNS:"
    $label.Location = New-Object Drawing.Point(10, 20)
    $label.Size = New-Object Drawing.Size(150, 20)
    $inputForm.Controls.Add($label)

    # Campo de entrada para o DNS
    $dnsInput = New-Object Windows.Forms.TextBox
    $dnsInput.Location = New-Object Drawing.Point(160, 20)
    $dnsInput.Size = New-Object Drawing.Size(200, 20)
    $inputForm.Controls.Add($dnsInput)

    # Botão para confirmar a mudança de DNS
    $okButton = New-Object Windows.Forms.Button
    $okButton.Text = "Alterar DNS"
    $okButton.Location = New-Object Drawing.Point(10, 60)
    $okButton.Size = New-Object Drawing.Size(75, 30)
    $okButton.Add_Click({
        $newDns = $dnsInput.Text

        # Validar o DNS (simples validação)
        if ($newDns -match "^\d{1,3}(\.\d{1,3}){3}$") {
            Set-DnsServer $newDns
            [System.Windows.Forms.MessageBox]::Show("DNS alterado para: $newDns", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $inputForm.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("O DNS inserido nao e valido. Por favor, insira um DNS valido.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $inputForm.Controls.Add($okButton)

    # Botão para cancelar
    $cancelButton = New-Object Windows.Forms.Button
    $cancelButton.Text = "Cancelar"
    $cancelButton.Location = New-Object Drawing.Point(95, 60)
    $cancelButton.Size = New-Object Drawing.Size(75, 30)
    $cancelButton.Add_Click({
        $inputForm.Close()
    })
    $inputForm.Controls.Add($cancelButton)

    # Botão para resetar o DNS para o padrão (DHCP)
    $resetButton = New-Object Windows.Forms.Button
    $resetButton.Text = "Resetar DNS"
    $resetButton.Location = New-Object Drawing.Point(179, 60)
    $resetButton.Size = New-Object Drawing.Size(90, 30)
    $resetButton.Add_Click({
        Reset-Dns
        $inputForm.Close()
    })
    $inputForm.Controls.Add($resetButton)

    #Refreshe no dns caso ele nao apare
    $refreshDnsButton = New-Object Windows.Forms.Button
    $refreshDnsButton.Text = "Refresh"
    $refreshDnsButton.Location = New-Object Drawing.Point(284, 60)
    $refreshDnsButton.Size = New-Object Drawing.Size(90, 30)
    $refreshDnsButton.Add_Click({
        Get-DnsActive
        $inputForm.Close()
    })
    $inputForm.Controls.Add($refreshDnsButton)

    # Exibe o formulário
    $inputForm.ShowDialog()
}


# ------------------------------------------------- Daqui pra baixo é so label -------------------------------------------------

# Adiciona o Label para mostrar o IP atual na parte inferior esquerda
$ipLabel = New-Object Windows.Forms.Label
$ipLabel.Location = New-Object Drawing.Point(10,230)  # Posiciona o Label na parte inferior esquerda
$ipLabel.Size = New-Object Drawing.Size(220, 30)  # Define o tamanho do Label
$ipLabel.Text = "IP Atual: " + (Get-ActualIp)
$form.Controls.Add($ipLabel)

# Atualiza o IP quando o formulário for redimensionado


# Atualiza o texto do IP a cada 10 segundos
# $timer = New-Object System.Windows.Forms.Timer
# $timer.Interval = 10000  # Intervalo de 10 segundos
# $timer.Add_Tick({
#     $ipLabel.Text = "IP Atual: " + (Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.PrefixLength -eq 24} | Select-Object -First 1).IPAddress
# })
# $timer.Start()


# Label para mostrar o IP público, inicialmente oculta
$publicIPLabel = New-Object Windows.Forms.Label
$publicIPLabel.Location = New-Object Drawing.Point(300,230)  # Posiciona a Label na parte inferior esquerda
$publicIPLabel.Size = New-Object Drawing.Size(220, 30)  # Define o tamanho do Label
$publicIPLabel.Text ="IP Publico: *** *** *** ***"  # Inicialmente oculta
$form.Controls.Add($publicIPLabel)

# Alterando o evento do botão "Ver IP Público"
$publicIPButton.Add_Click({
    $publicIPLabel.Text = "IP Publico:" + (Get-PublicIP)
    $publicIPLabel.ForeColor = [System.Drawing.Color]::Red
    # Mostrar a label com IP público
    # $publicIPLabel.Visible = $true  # Torna visível a label de IP público
})

#Adicona label do dns atual
$dnsLabel = New-Object Windows.Forms.Label
$dnsLabel.Location = New-Object Drawing.Point(600,230)  # Posiciona o Label na parte inferior esquerda
$dnsLabel.Size = New-Object Drawing.Size(220, 30)  # Define o tamanho do Label
$dnsLabel.Text = "DNS atual:" + (Get-DnsActive)
$form.Controls.Add($dnsLabel)


# #String global
# $globalStringLabel = New-Object Windows.Forms.Label
# $globalStringLabel.Location = New-Object Drawing.Point(10,300)  # Posiciona o Label na parte inferior esquerda
# $globalStringLabel.Size = New-Object Drawing.Size(800, 30)  # Define o tamanho do Label
# $globalStringLabel.Text = "IP Atual: " + (Get-ActualIp)+ "   IP publico:" + (Get-PublicIP) + "   DNS atual:" + (Get-DnsActive)
# $form.Controls.Add($globalStringLabel)

# Função para mudar o DNS


# Exibir a janela
$form.Add_Shown({$form.Activate()})
[Windows.Forms.Application]::Run($form)
