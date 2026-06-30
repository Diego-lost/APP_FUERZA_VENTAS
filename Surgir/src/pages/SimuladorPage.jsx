import { useState, useEffect } from 'react'
import { Calculator } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Alert from '../components/ui/Alert.jsx'
import Money from '../components/ui/Money.jsx'
import { calcularCredito } from '../utils/creditSimulator.js'
import { toNumber } from '../utils/format.js'

export default function SimuladorPage() {
  const [monto, setMonto] = useState('3000')
  const [plazo, setPlazo] = useState('12')
  const [tea, setTea] = useState(60)
  const [result, setResult] = useState(null)
  const [error, setError] = useState(null)

  const calcular = () => {
    const m = toNumber(monto)
    const p = parseInt(plazo, 10)
    if (m <= 0 || !p || p <= 0) {
      setError('Ingresa monto y plazo válidos.')
      setResult(null)
      return
    }
    setError(null)
    setResult(calcularCredito({ monto: m, plazoMeses: p, teaPorcentaje: tea }))
  }

  useEffect(() => { calcular() }, [])

  return (
    <>
      <PageHead
        title="Simulador de crédito"
        subtitle="Cuota mensual y cronograma con amortización francesa (RF-47)."
        icon={Calculator}
      />
      {error && <Alert tipo="error">{error}</Alert>}

      <Card title="Parámetros" icon={Calculator}>
        <div className="hb-grid-2">
          <div className="hb-field">
            <label>Monto (S/)</label>
            <input className="hb-input" value={monto} onChange={(e) => setMonto(e.target.value)} />
          </div>
          <div className="hb-field">
            <label>Plazo (meses)</label>
            <input className="hb-input" value={plazo} onChange={(e) => setPlazo(e.target.value)} />
          </div>
          <div className="hb-field" style={{ gridColumn: '1 / -1' }}>
            <label>TEA referencial: {tea.toFixed(0)}%</label>
            <input
              type="range"
              min={40}
              max={80}
              step={5}
              value={tea}
              onChange={(e) => setTea(Number(e.target.value))}
              style={{ width: '100%' }}
            />
          </div>
          <div style={{ gridColumn: '1 / -1' }}>
            <button className="hb-btn" onClick={calcular}><Calculator size={16} /> Calcular cuota</button>
          </div>
        </div>
      </Card>

      {result && (
        <>
          <Card title="Resultado" style={{ marginTop: 16 }}>
            <dl className="cm-dl">
              <div><dt>Cuota mensual</dt><dd><Money value={result.cuotaMensual} /></dd></div>
              <div><dt>Total a pagar</dt><dd><Money value={result.totalPagar} /></dd></div>
              <div><dt>Costo financiero</dt><dd><Money value={result.costoFinanciero} /></dd></div>
              <div><dt>TEA usada</dt><dd>{result.teaReferencial.toFixed(0)}%</dd></div>
            </dl>
          </Card>

          <Card title="Cronograma de cuotas" style={{ marginTop: 16 }}>
            <div className="hb-table-wrap">
              <table className="hb-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th className="num">Cuota</th>
                    <th className="num">Capital</th>
                    <th className="num">Interés</th>
                    <th className="num">Saldo</th>
                  </tr>
                </thead>
                <tbody>
                  {result.cronograma.map((c) => (
                    <tr key={c.nroCuota}>
                      <td>{c.nroCuota}</td>
                      <td className="num"><Money value={c.montoCuota} /></td>
                      <td className="num"><Money value={c.montoCapital} /></td>
                      <td className="num"><Money value={c.montoInteres} /></td>
                      <td className="num"><Money value={c.saldo} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </>
      )}
    </>
  )
}
